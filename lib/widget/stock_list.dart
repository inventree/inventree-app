
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:infinite_scroll_pagination/infinite_scroll_pagination.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";

import "package:inventree/l10.dart";
import "package:inventree/app_settings.dart";
import "package:inventree/widget/stock_detail.dart";

import "package:inventree/api.dart";

class StockItemList extends StatefulWidget {

  const StockItemList(this.filters);

  final Map<String, String> filters;

  @override
  _StockListState createState() => _StockListState(filters);
}


class _StockListState extends RefreshableState<StockItemList> {

  _StockListState(this.filters);

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => L10().purchaseOrders;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedStockItemList(filters);
  }
}

class PaginatedStockItemList extends StatefulWidget {

  const PaginatedStockItemList(this.filters);

  final Map<String, String> filters;

  @override
  _PaginatedStockItemListState createState() => _PaginatedStockItemListState(filters);
  
}


class _PaginatedStockItemListState extends State<PaginatedStockItemList> {

  _PaginatedStockItemListState(this.filters);

  static const _pageSize = 25;

  String _searchTerm = "";

  final Map<String, String> filters;

  final PagingController<int, InvenTreeStockItem> _pagingController = PagingController(firstPageKey: 0);

  @override
  String getAppbarTitle(BuildContext context) => L10().stockItems;

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

      Map<String, String> params = filters;

      params["search"] = "${_searchTerm}";

      // Do we include stock items from sub-locations?
      final bool cascade = await InvenTreeSettingsManager().getBool("stockSublocation", true);

      params["cascade"] = "${cascade}";

      final page = await InvenTreeStockItem().listPaginated(_pageSize, pageKey, filters: params);

      int pageLength = page?.length ?? 0;
      int pageCount = page?.count ?? 0;

      final isLastPage = pageLength < _pageSize;

      // Construct a list of stock item objects
      List<InvenTreeStockItem> items = [];

      if (page != null) {
        for (var result in page.results) {
          if (result is InvenTreeStockItem) {
            items.add(result);
          }
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        final int nextPageKey = pageKey + pageLength;
        _pagingController.appendPage(items, nextPageKey);
      }

      setState(() {
        resultCount = pageCount;
      });

    } catch (error, stackTrace) {
      _pagingController.error = error;

      sentryReportError(error, stackTrace);
    }
  }

  void _openItem(BuildContext context, int pk) {
    InvenTreeStockItem().get(pk).then((var item) {
      if (item is InvenTreeStockItem) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
      }
    });
  }

  Widget _buildItem(BuildContext context, InvenTreeStockItem item) {
    return ListTile(
      title: Text("${item.partName}"),
      subtitle: Text("${item.locationPathString}"),
      leading: InvenTreeAPI().getImage(
        item.partThumbnail,
        width: 40,
        height: 40,
      ),
      trailing: Text("${item.displayQuantity}",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: item.statusColor,
        ),
      ),
      onTap: () {
        _openItem(context, item.pk);
      },
    );
  }

  final TextEditingController searchController = TextEditingController();

  void updateSearchTerm() {
    _searchTerm = searchController.text;
    _pagingController.refresh();
  }

  @override
  Widget build (BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          PaginatedSearchWidget(searchController, updateSearchTerm, resultCount),
          Expanded(
              child: CustomScrollView(
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  slivers: <Widget>[
                    // TODO - Search input
                    PagedSliverList.separated(
                      pagingController: _pagingController,
                      builderDelegate: PagedChildBuilderDelegate<InvenTreeStockItem>(
                          itemBuilder: (context, item, index) {
                            return _buildItem(context, item);
                          },
                          noItemsFoundIndicatorBuilder: (context) {
                            return NoResultsWidget("No stock items found");
                          }
                      ),
                      separatorBuilder: (context, item) => const Divider(height: 1),
                    )
                  ]
              )
          )
        ]
    );
  }
}