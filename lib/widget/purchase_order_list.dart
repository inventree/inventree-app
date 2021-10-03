import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:infinite_scroll_pagination/infinite_scroll_pagination.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/purchase_order_detail.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/purchase_order.dart";

/*
 * Widget class for displaying a list of Purchase Orders
 */
class PurchaseOrderListWidget extends StatefulWidget {

  const PurchaseOrderListWidget({this.filters = const {}, Key? key}) : super(key: key);

  final Map<String, String> filters;

  @override
  _PurchaseOrderListWidgetState createState() => _PurchaseOrderListWidgetState(filters);
}


class _PurchaseOrderListWidgetState extends RefreshableState<PurchaseOrderListWidget> {

  _PurchaseOrderListWidgetState(this.filters);

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => L10().purchaseOrders;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPurchaseOrderList(filters);
  }
}


class PaginatedPurchaseOrderList extends StatefulWidget {

  const PaginatedPurchaseOrderList(this.filters, {this.onTotalChanged});

  final Map<String, String> filters;

  final Function(int)? onTotalChanged;

  @override
  _PaginatedPurchaseOrderListState createState() => _PaginatedPurchaseOrderListState(filters, onTotalChanged);

}


class _PaginatedPurchaseOrderListState extends State<PaginatedPurchaseOrderList> {

  _PaginatedPurchaseOrderListState(this.filters, this.onTotalChanged);

  static const _pageSize = 25;

  String _searchTerm = "";

  Function(int)? onTotalChanged;

  final Map<String, String> filters;

  final PagingController<int, InvenTreePurchaseOrder> _pagingController = PagingController(firstPageKey: 0);

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });

    super.initState();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  int resultCount = 0;

  Future<void> _fetchPage(int pageKey) async {
    try {
      Map<String, String> params = {};

      params["search"] = _searchTerm;

      // Only return results for open purchase orders
      params["outstanding"] = "true";

      // Copy across provided filters
      for (String key in filters.keys) {
        params[key] = filters[key] ?? "";
      }

      final page = await InvenTreePurchaseOrder().listPaginated(
        _pageSize,
        pageKey,
        filters: params
      );

      int pageLength = page?.length ?? 0;
      int pageCount = page?.count ?? 0;

      final isLastPage = pageLength < _pageSize;

      List<InvenTreePurchaseOrder> orders = [];

      if (page != null) {
        for (var result in page.results) {
          if (result is InvenTreePurchaseOrder) {
            orders.add(result);
          } else {
            print("Result is not valid PurchaseOrder:");
            print(result.jsondata);
          }
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(orders);
      } else {
        final int nextPageKey = pageKey + pageLength;
        _pagingController.appendPage(orders, nextPageKey);
      }

      if (onTotalChanged != null) {
        onTotalChanged!(pageCount);
      }

      setState(() {
        resultCount = pageCount;
      });
    } catch (error, stackTrace) {
      print("Error! - ${error.toString()}");
      _pagingController.error = error;

      sentryReportError(error, stackTrace);
    }
  }

  void updateSearchTerm() {
    _searchTerm = searchController.text;
    _pagingController.refresh();
  }

  Widget _buildOrder(BuildContext context, InvenTreePurchaseOrder order) {

    InvenTreeCompany? supplier = order.supplier;

    return ListTile(
      title: Text(order.reference),
      subtitle: Text(order.description),
      leading: supplier == null ? null : InvenTreeAPI().getImage(
        supplier.thumbnail,
        width: 40,
        height: 40,
      ),
      trailing: Text("${order.lineItemCount}"),
      onTap: () async {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseOrderDetailWidget(order)
          )
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        PaginatedSearchWidget(searchController, updateSearchTerm, resultCount),
        Expanded(
            child: CustomScrollView(
              shrinkWrap: true,
              physics: ClampingScrollPhysics(),
              scrollDirection: Axis.vertical,
              slivers: [
                PagedSliverList.separated(
                  pagingController: _pagingController,
                  builderDelegate: PagedChildBuilderDelegate<InvenTreePurchaseOrder>(
                      itemBuilder: (context, item, index) {
                        return _buildOrder(context, item);
                      },
                      noItemsFoundIndicatorBuilder: (context) {
                        return NoResultsWidget(L10().companyNoResults);
                      }
                  ),
                  separatorBuilder: (context, index) => const Divider(height: 1),
                )
              ],
            )
        )
      ],
    );
  }
}