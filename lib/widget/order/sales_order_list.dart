
import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/order/sales_order_detail.dart";
import "package:inventree/widget/paginator.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";


class SalesOrderListWidget extends StatefulWidget {

  const SalesOrderListWidget({this.filters = const {}, Key? key}) : super(key: key);

  final Map<String, String> filters;

  @override
  _SalesOrderListWidgetState createState() => _SalesOrderListWidgetState();

}

class _SalesOrderListWidgetState extends RefreshableState<SalesOrderListWidget> {

  _SalesOrderListWidgetState();

  @override
  String getAppBarTitle() => L10().salesOrders;

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreeSalesOrder().canCreate) {
      actions.add(
          SpeedDialChild(
              child: FaIcon(FontAwesomeIcons.circlePlus),
              label: L10().salesOrderCreate,
              onTap: () {
                _createSalesOrder(context);
              }
          )
      );
    }

    return actions;
  }

  Future<void> _createSalesOrder(BuildContext context) async {
    // TODO: Create new sales order
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    // TODO: return custom barcode actions
    return [];
  }

  @override
  Widget getBody(BuildContext context) {
    return PaginatedSalesOrderList(widget.filters);
  }

}


class PaginatedSalesOrderList extends PaginatedSearchWidget {

  const PaginatedSalesOrderList(Map<String, String> filters) : super(filters: filters);

  @override
  String get searchTitle => L10().salesOrders;

  @override
  _PaginatedSalesOrderListState createState() => _PaginatedSalesOrderListState();

}


class _PaginatedSalesOrderListState extends PaginatedSearchState<PaginatedSalesOrderList> {

  _PaginatedSalesOrderListState() : super();

  @override
  String get prefix => "so_";

  @override
  Map<String, String> get orderingOptions => {
    // TODO: Custom ordering options
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    // TODO: Custom filtering options
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    await InvenTreeAPI().SalesOrderStatus.load();
    final page = await InvenTreeSalesOrder().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreeSalesOrder order = model as InvenTreeSalesOrder;

    InvenTreeCompany? customer = order.customer;

    return ListTile(
      title: Text(order.reference),
      subtitle: Text(order.description),
      leading: customer == null ? null : InvenTreeAPI().getThumbnail(customer.thumbnail),
      trailing: Text(
        InvenTreeAPI().SalesOrderStatus.label(order.status),
        style: TextStyle(
          color: InvenTreeAPI().SalesOrderStatus.color(order.status),
        )
      ),
      onTap: () async {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SalesOrderDetailWidget(order)
          )
        );
      }
    );

  }

}