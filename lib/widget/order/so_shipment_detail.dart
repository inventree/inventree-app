/*
 * Widget for displaying detail view of a single SalesOrderShipment
 */

import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

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
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.shipment.canEdit) {
      actions.add(
        IconButton(
          icon: Icon(TablerIcons.edit),
          onPressed: () {
            _editShipment(context);
          },
        ),
      );
    }

    return actions;
  }

  Future<void> _editShipment(BuildContext context) async {
    var fields = widget.shipment.formFields();

    fields["order"]?["hidden"] = true;

    widget.shipment.editForm(
      context,
      L10().shipmentEdit,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().shipmentUpdated, success: true);
      }
    );
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // TODO
    return tiles;
  }
}