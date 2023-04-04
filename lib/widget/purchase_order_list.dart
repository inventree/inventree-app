import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
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

  bool showFilterOptions = false;

  @override
  String getAppBarTitle(BuildContext context) => L10().purchaseOrders;

  @override
  List<Widget> getAppBarActions(BuildContext context) => [
    IconButton(
      icon: FaIcon(FontAwesomeIcons.filter),
      onPressed: () async {
        setState(() {
          showFilterOptions = !showFilterOptions;
        });
      },
    )
  ];

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPurchaseOrderList(filters, showFilterOptions);
  }
}


class PaginatedPurchaseOrderList extends PaginatedSearchWidget {

  const PaginatedPurchaseOrderList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedPurchaseOrderListState createState() => _PaginatedPurchaseOrderListState();

}


class _PaginatedPurchaseOrderListState extends PaginatedSearchState<PaginatedPurchaseOrderList> {

  _PaginatedPurchaseOrderListState() : super();

  @override
  String get prefix => "po_";

  @override
  Map<String, String> get orderingOptions => {
    "reference": L10().reference,
    "supplier__name": L10().supplier,
    "status": L10().status,
    "target_date": L10().targetDate,
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    params["outstanding"] = "true";

    final page = await InvenTreePurchaseOrder().listPaginated(limit, offset, filters: params);

    return page;

  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreePurchaseOrder order = model as InvenTreePurchaseOrder;

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
}