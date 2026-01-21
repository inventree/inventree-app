import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/paginator.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";

class SalesOrderListWidget extends StatefulWidget {
  const SalesOrderListWidget({this.filters = const {}, Key? key})
    : super(key: key);

  final Map<String, String> filters;

  @override
  _SalesOrderListWidgetState createState() => _SalesOrderListWidgetState();
}

class _SalesOrderListWidgetState
    extends RefreshableState<SalesOrderListWidget> {
  _SalesOrderListWidgetState();

  @override
  String getAppBarTitle() => L10().salesOrders;

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreeSalesOrder().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.circle_plus),
          label: L10().salesOrderCreate,
          onTap: () {
            _createSalesOrder(context);
          },
        ),
      );
    }

    return actions;
  }

  // Launch form to create a new SalesOrder
  Future<void> _createSalesOrder(BuildContext context) async {
    var fields = InvenTreeSalesOrder().formFields();

    // Cannot set contact until company is locked in
    fields.remove("contact");

    InvenTreeSalesOrder().createForm(
      context,
      L10().salesOrderCreate,
      fields: fields,
      onSuccess: (result) async {
        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var order = InvenTreeSalesOrder.fromJson(data);
          order.goToDetailPage(context);
        }
      },
    );
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
  const PaginatedSalesOrderList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().salesOrders;

  @override
  _PaginatedSalesOrderListState createState() =>
      _PaginatedSalesOrderListState();
}

class _PaginatedSalesOrderListState
    extends PaginatedSearchState<PaginatedSalesOrderList> {
  _PaginatedSalesOrderListState() : super();

  @override
  String get prefix => "so_";

  @override
  Map<String, String> get orderingOptions => {
    "reference": L10().reference,
    "status": L10().status,
    "target_date": L10().targetDate,
    "customer__name": L10().customer,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "outstanding": {
      "label": L10().outstanding,
      "help_text": L10().outstandingOrderDetail,
      "tristate": true,
      "default": true,
    },
    "overdue": {
      "label": L10().overdue,
      "help_text": L10().overdueDetail,
      "tristate": true,
    },
    "assigned_to_me": {
      "label": L10().assignedToMe,
      "help_text": L10().assignedToMeDetail,
      "tristate": true,
    },
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    await InvenTreeAPI().SalesOrderStatus.load();
    final page = await InvenTreeSalesOrder().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeSalesOrder order = model as InvenTreeSalesOrder;

    InvenTreeCompany? customer = order.customer;

    // Build subtitle with customer name and optional total price
    String subtitle = customer?.name ?? order.description;
    if (order.totalPrice != null && order.totalPrice! > 0) {
      subtitle +=
          " • ${order.totalPriceCurrency} ${order.totalPrice!.toStringAsFixed(2)}";
    }

    return ListTile(
      title: Text(order.reference),
      subtitle: Text(subtitle),
      leading: customer == null
          ? null
          : InvenTreeAPI().getThumbnail(customer.thumbnail),
      trailing: LargeText(
        InvenTreeAPI().SalesOrderStatus.label(order.status),
        color: InvenTreeAPI().SalesOrderStatus.color(order.status),
      ),
      onTap: () async {
        order.goToDetailPage(context);
      },
    );
  }
}
