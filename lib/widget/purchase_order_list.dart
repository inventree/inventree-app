import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:infinite_scroll_pagination/infinite_scroll_pagination.dart";

import "package:inventree/inventree/company.dart";
import 'package:inventree/inventree/model.dart';
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

  const PaginatedPurchaseOrderList(this.filters);

  final Map<String, String> filters;

  @override
  _PaginatedPurchaseOrderListState createState() => _PaginatedPurchaseOrderListState(filters);

}


class _PaginatedPurchaseOrderListState extends PaginatedSearchState<PaginatedPurchaseOrderList> {

  _PaginatedPurchaseOrderListState(Map<String, String> filters) : super(filters);

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