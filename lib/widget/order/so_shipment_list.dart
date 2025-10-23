import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/paginator.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/l10.dart";

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

    return ListTile(
      title: Text(shipment.reference),
      subtitle: Text(shipment.tracking_number),
      onTap: () async {
        shipment.goToDetailPage(context);
      },
      leading: shipment.shipped
          ? Icon(TablerIcons.calendar_check, color: COLOR_SUCCESS)
          : Icon(TablerIcons.calendar_cancel, color: COLOR_WARNING),
      trailing: shipment.shipped
          ? LargeText(shipment.shipment_date ?? "")
          : null,
    );
  }
}
