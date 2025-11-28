/*
 * Widget for displaying detail view of a single SalesOrderShipment
 */

import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
import "package:inventree/api_form.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/attachment.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/order/so_allocation_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

class SOShipmentDetailWidget extends StatefulWidget {
  const SOShipmentDetailWidget(this.shipment, {Key? key}) : super(key: key);

  final InvenTreeSalesOrderShipment shipment;

  @override
  _SOShipmentDetailWidgetState createState() => _SOShipmentDetailWidgetState();
}

class _SOShipmentDetailWidgetState
    extends RefreshableState<SOShipmentDetailWidget> {
  _SOShipmentDetailWidgetState();

  // The SalesOrder associated with this shipment
  InvenTreeSalesOrder? order;

  int attachmentCount = 0;
  bool showCameraShortcut = true;

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
      },
    );
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.shipment.reload();

    showCameraShortcut = await InvenTreeSettingsManager().getBool(
      INV_SO_SHOW_CAMERA,
      true,
    );

    final so = await InvenTreeSalesOrder().get(widget.shipment.orderId);

    if (mounted) {
      setState(() {
        order = (so is InvenTreeSalesOrder ? so : null);
      });
    }

    InvenTreeAttachment()
        .countAttachments(
          InvenTreeSalesOrderShipment.MODEL_TYPE,
          widget.shipment.pk,
        )
        .then((int value) {
          if (mounted) {
            setState(() {
              attachmentCount = value;
            });
          }
        });
  }

  /// Upload an image for this shipment
  Future<void> _uploadImage(BuildContext context) async {
    InvenTreeAttachment()
        .uploadImage(
          InvenTreeSalesOrderShipment.MODEL_TYPE,
          widget.shipment.pk,
          prefix: widget.shipment.reference,
        )
        .then((result) => refresh(context));
  }

  /// Mark this shipment as shipped
  Future<void> _sendShipment(BuildContext context) async {
    Map<String, dynamic> fields = {
      "shipment_date": {
        "value": widget.shipment.isShipped
            ? widget.shipment.shipment_date!
            : DateTime.now().toIso8601String().split("T").first,
      },
      "tracking_number": {"value": widget.shipment.tracking_number},
      "invoice_number": {"value": widget.shipment.invoice_number},
    };

    launchApiForm(
      context,
      L10().shipmentSend,
      widget.shipment.SHIP_SHIPMENT_URL,
      fields,
      method: "POST",
      onSuccess: (data) {
        refresh(context);
        showSnackIcon(L10().shipmentUpdated, success: true);
      },
    );
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (!widget.shipment.canEdit) {
      // Exit early if we do not have edit permissions
      return actions;
    }

    if (showCameraShortcut) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.camera, color: Colors.blue),
          label: L10().takePicture,
          onTap: () async {
            _uploadImage(context);
          },
        ),
      );
    }

    // Check shipment
    if (!widget.shipment.isChecked && !widget.shipment.isShipped) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.check, color: Colors.green),
          label: L10().shipmentCheck,
          onTap: () async {
            widget.shipment
                .update(values: {"checked_by": InvenTreeAPI().userId})
                .then((_) {
                  showSnackIcon(L10().shipmentUpdated, success: true);
                  refresh(context);
                });
          },
        ),
      );
    }

    // Uncheck shipment
    if (widget.shipment.isChecked && !widget.shipment.isShipped) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.x, color: Colors.red),
          label: L10().shipmentUncheck,
          onTap: () async {
            widget.shipment.update(values: {"checked_by": null}).then((_) {
              showSnackIcon(L10().shipmentUpdated, success: true);
              refresh(context);
            });
          },
        ),
      );
    }

    // Send shipment
    if (!widget.shipment.isShipped) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.truck_delivery, color: Colors.green),
          label: L10().shipmentSend,
          onTap: () async {
            _sendShipment(context);
          },
        ),
      );
    }

    // TODO: Cancel shipment

    return actions;
  }

  List<Widget> shipmentTiles(BuildContext context) {
    List<Widget> tiles = [];

    final bool checked = widget.shipment.isChecked;
    final bool shipped = widget.shipment.isShipped;
    final bool delivered = widget.shipment.isDelivered;

    // Order information
    if (order != null) {
      // Add SalesOrder information

      tiles.add(
        Card(
          child: ListTile(
            title: Text(order!.reference),
            subtitle: Text(order!.description),
            leading: api.getThumbnail(order!.customer?.thumbnail ?? ""),
            trailing: LargeText(
              api.SalesOrderStatus.label(order!.status),
              color: api.SalesOrderStatus.color(order!.status),
            ),
            onTap: () {
              order!.goToDetailPage(context);
            },
          ),
        ),
      );
    }

    // Shipment reference number
    tiles.add(
      ListTile(
        title: Text(L10().shipmentReference),
        trailing: LargeText(widget.shipment.reference),
        leading: Icon(TablerIcons.hash),
      ),
    );

    if (widget.shipment.invoice_number.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().invoiceNumber),
          trailing: LargeText(widget.shipment.invoice_number),
          leading: Icon(TablerIcons.invoice),
        ),
      );
    }

    // Tracking Number
    if (widget.shipment.tracking_number.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().trackingNumber),
          trailing: LargeText(widget.shipment.tracking_number),
          leading: Icon(TablerIcons.truck_delivery),
        ),
      );
    }

    if (checked || !shipped) {
      tiles.add(
        ListTile(
          title: Text(L10().shipmentChecked),
          trailing: LargeText(
            checked ? L10().yes : L10().no,
            color: checked ? COLOR_SUCCESS : COLOR_WARNING,
          ),
          leading: Icon(
            checked ? TablerIcons.circle_check : TablerIcons.circle_x,
            color: checked ? COLOR_SUCCESS : COLOR_WARNING,
          ),
        ),
      );
    }

    tiles.add(
      ListTile(
        title: Text(L10().shipmentDate),
        trailing: LargeText(
          shipped ? widget.shipment.shipment_date! : L10().notApplicable,
        ),
        leading: Icon(
          shipped ? TablerIcons.calendar_check : TablerIcons.calendar_cancel,
          color: shipped ? COLOR_SUCCESS : COLOR_WARNING,
        ),
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().deliveryDate),
        trailing: LargeText(
          delivered ? widget.shipment.delivery_date! : L10().notApplicable,
        ),
        leading: Icon(
          delivered ? TablerIcons.calendar_check : TablerIcons.calendar_cancel,
          color: delivered ? COLOR_SUCCESS : COLOR_WARNING,
        ),
      ),
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
            MaterialPageRoute(
              builder: (context) => NotesWidget(widget.shipment),
            ),
          );
        },
      ),
    );

    ListTile? attachmentTile = ShowAttachmentsItem(
      context,
    InvenTreeSalesOrderShipment.MODEL_TYPE,
      widget.shipment.pk,
      widget.shipment.reference,
      attachmentCount,
      widget.shipment.canEdit,
    );

    if (attachmentTile != null) {
      tiles.add(attachmentTile);
    }

    return tiles;
  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    return [Tab(text: L10().details), Tab(text: L10().allocatedStock)];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      ListView(children: shipmentTiles(context)),
      PaginatedSOAllocationList({
        "order": widget.shipment.orderId.toString(),
        "shipment": widget.shipment.pk.toString(),
      }),
    ];
  }
}
