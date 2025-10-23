/*
 * Widget for displaying detail view of a single SalesOrderShipment
 */

import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/notes_widget.dart";
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

  // The SalesOrder associated with this shipment
  InvenTreeSalesOrder? order;

  int attachmentCount = 0;

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
  Future<void> request(BuildContext context) async {
    await widget.shipment.reload();

    final so = await InvenTreeSalesOrder().get(widget.shipment.orderId);

    if (mounted) {
      setState(() {
        order = (so is InvenTreeSalesOrder ? so : null);
      });
    }

    InvenTreeSalesOrderShipmentAttachment().countAttachments(widget.shipment.pk).then((
        int value,
        ) {
      if (mounted) {
        setState(() {
          attachmentCount = value;
        });
      }
    });
  }

  List<Widget> shipmentTiles(BuildContext context) {
    List<Widget> tiles = [];

    final bool checked = widget.shipment.isChecked;
    final bool shipped = widget.shipment.isShipped;
    final bool delivered = widget.shipment.isDelivered;

    // Order information
    if (order != null) {
      // Add SalesOrder information

      // TODO: Customer information
    }


    // Shipment reference number
    tiles.add(
      ListTile(
        title: Text(L10().reference),
        trailing: LargeText(widget.shipment.reference),
        leading: Icon(TablerIcons.hash),
      )
    );

    if (widget.shipment.invoice_number.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().invoiceNumber),
          trailing: LargeText(widget.shipment.invoice_number),
          leading: Icon(TablerIcons.invoice)
        )
      );
    }

    // Tracking Number
    if (widget.shipment.tracking_number.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().trackingNumber),
          trailing: LargeText(widget.shipment.tracking_number),
          leading: Icon(TablerIcons.truck_delivery),
        )
      );
    }

    if (checked || !shipped) {
      tiles.add(
          ListTile(
            title: Text(L10().shipmentChecked),
            trailing: LargeText(checked ? L10().yes : L10().no),
            leading: Icon(
              checked ? TablerIcons.circle_check : TablerIcons.circle_x,
              color: checked ? COLOR_SUCCESS : COLOR_WARNING,
            ),
          )
      );
    }

    tiles.add(
      ListTile(
        title: Text(L10().shipmentDate),
        trailing: LargeText(shipped ? widget.shipment.shipment_date ?? "" : ""),
        leading: Icon(shipped ? TablerIcons.calendar_check : TablerIcons.calendar_cancel, color: shipped ? COLOR_SUCCESS : COLOR_WARNING)
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().deliveryDate),
        trailing: LargeText(delivered ? widget.shipment.delivery_date ?? "" : ""),
        leading: Icon(delivered ? TablerIcons.calendar_check : TablerIcons.calendar_cancel, color: delivered ? COLOR_SUCCESS : COLOR_WARNING)
      )
    );

    // External link
    if (widget.shipment.hasLink) {
      tiles.add(
        ListTile(
          title: Text(L10().link),
          leading: Icon(TablerIcons.link, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () async {
            widget.shipment.openLink();
          },
        ),
      );
    }

    // Notes tile
    tiles.add(
      ListTile(
        title: Text(L10().notes),
        leading: Icon(TablerIcons.note, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesWidget(widget.shipment)),
          );
        },
      ),
    );

    // Attachments
    tiles.add(
      ListTile(
        title: Text(L10().attachments),
        leading: Icon(TablerIcons.file, color: COLOR_ACTION),
        trailing: LinkIcon(
          text: attachmentCount > 0 ? attachmentCount.toString() : null,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttachmentWidget(
                InvenTreeSalesOrderShipmentAttachment(),
                widget.shipment.pk,
                widget.shipment.reference,
                widget.shipment.canEdit,
              ),
            ),
          );
        },
      ),
    );

    // TODO
    return tiles;
  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    return [
      Tab(text: L10().details),
    ];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      ListView(children: shipmentTiles(context)),    ];
  }

}