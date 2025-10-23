/*
 * Widget for displaying detail view of a single SalesOrderShipment
 */

import "package:flutter/cupertino.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/refreshable_state.dart";

class SOShipmentDetailWidget extends StatefulWidget {

  const SOShipmentDetailWidget(this.shipment, {Key? key}) : super(key: key);

  final InvenTreeSalesOrderShipment shipment;

  @override
  _SOShipmentDetailWidgetState createState() => _SOShipmentDetailWidgetState();
}

class _SOShipmentDetailWidgetState extends RefreshableState<SOShipmentDetailWidget> {

  _SOShipmentDetailWidgetState();

  @override
  String getAppBarTitle() => L10().shipment;

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // TODO
    return tiles;
  }
}