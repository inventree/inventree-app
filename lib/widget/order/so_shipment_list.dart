import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/paginator.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/refreshable_state.dart";

class SOShipmentListWidget extends StatefulWidget {
  const SOShipmentListWidget({
    this.title = "",
    this.filters = const {},
    Key? key,
  }) : super(key: key);

  final Map<String, String> filters;

  final String title;

  @override
  _SOShipmentListWidgetState createState() => _SOShipmentListWidgetState();
}

class _SOShipmentListWidgetState
    extends RefreshableState<SOShipmentListWidget> {
  _SOShipmentListWidgetState();

  @override
  String getAppBarTitle() => widget.title;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedSOShipmentList(widget.filters);
  }
}

class PaginatedSOShipmentList extends PaginatedSearchWidget {
  const PaginatedSOShipmentList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().shipments;

  @override
  _PaginatedSOShipmentListState createState() =>
      _PaginatedSOShipmentListState();
}

class _PaginatedSOShipmentListState
    extends PaginatedSearchState<PaginatedSOShipmentList> {
  _PaginatedSOShipmentListState() : super();

  @override
  String get prefix => "so_shipment_";

  @override
  Map<String, String> get orderingOptions => {};

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {};

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeSalesOrderShipment().listPaginated(
      limit,
      offset,
      filters: params,
    );
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeSalesOrderShipment shipment = model as InvenTreeSalesOrderShipment;

    InvenTreeSalesOrder? order = shipment.order;
    return ListTile(
      title: Text(
        "${order?.reference ?? L10().salesOrder} - ${shipment.reference}",
      ),
      subtitle: Text(order?.description ?? L10().description),
      onTap: () async {
        shipment.goToDetailPage(context);
      },
      leading: shipment.isShipped
          ? Icon(TablerIcons.calendar_check, color: COLOR_SUCCESS)
          : Icon(TablerIcons.calendar_cancel, color: COLOR_WARNING),
      trailing: shipment.isShipped
          ? LargeText(shipment.shipment_date ?? "")
          : LargeText(L10().pending),
    );
  }
}
