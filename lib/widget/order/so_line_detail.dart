

/*
 * Widget for displaying detail view of a single SalesOrderLineItem
 */

import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/sales_order.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/sales_order.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/part/part_detail.dart";
import "package:inventree/widget/snacks.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";
import "package:inventree/api_form.dart";


class SoLineDetailWidget extends StatefulWidget {

  const SoLineDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeSOLineItem item;

  @override
  _SOLineDetailWidgetState createState() => _SOLineDetailWidgetState();

}


class _SOLineDetailWidgetState extends RefreshableState<SoLineDetailWidget> {

  _SOLineDetailWidgetState();

  InvenTreeSalesOrder? order;

  @override
  String getAppBarTitle() => L10().lineItem;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.item.canEdit) {
      actions.add(
        IconButton(
            icon: Icon(Icons.edit_square),
            onPressed: () {
              _editLineItem(context);
            }),
      );
    }

    return actions;
  }

  Future<void> _allocateStock(BuildContext context) async {

    if (order == null) {
      return;
    }

    var fields = InvenTreeSOLineItem().allocateFormFields();

    fields["line_item"]?["value"] = widget.item.pk.toString();
    fields["stock_item"]?["filters"] = {
      "in_stock": true,
      "available": true,
      "part": widget.item.partId.toString()
    };
    fields["quantity"]?["value"] = widget.item.unallocatedQuantity.toString();
    fields["shipment"]?["filters"] = {
      "order": order!.pk.toString()
    };

    launchApiForm(
      context,
      L10().allocateStock,
      order!.allocate_url,
      fields,
      method: "POST",
      icon: FontAwesomeIcons.rightToBracket,
      onSuccess: (data) async {
        refresh(context);
      }
    );

  }

  Future<void> _editLineItem(BuildContext context) async {
    var fields = widget.item.formFields();

    // Prevent editing of the line item
    if (widget.item.shipped > 0) {
      fields["part"]?["hidden"] = true;
    }

    widget.item.editForm(
      context,
      L10().editLineItem,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().lineItemUpdated, success: true);
      }
    );
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {

    List<SpeedDialChild> buttons = [];

    if (order != null && order!.isOpen) {
      buttons.add(
        SpeedDialChild(
          child: FaIcon(FontAwesomeIcons.rightToBracket, color: Colors.blue),
          label: L10().allocateStock,
          onTap: () async {
            _allocateStock(context);
          }
        )
      );
    }

    return buttons;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (order != null && order!.isOpen && InvenTreeSOLineItem().canCreate) {

      if (api.supportsBarcodeSOAllocateEndpoint) {
        actions.add(
            SpeedDialChild(
              child: FaIcon(FontAwesomeIcons.rightToBracket),
              label: L10().allocateStock,
              onTap: () async {
                scanBarcode(
                  context,
                  handler: SOAllocateStockHandler(
                    salesOrder: order,
                    lineItem: widget.item
                  )
                );
              }
            )
        );
      }
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.item.reload();

    final so = await InvenTreeSalesOrder().get(widget.item.orderId);

    if (mounted) {
      setState(() {
        order = (so is InvenTreeSalesOrder ? so : null);
      });
    }
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Reference to the part
    tiles.add(
      ListTile(
        title: Text(L10().part),
        subtitle: Text(widget.item.partName),
        leading: FaIcon(FontAwesomeIcons.shapes, color: COLOR_ACTION),
        trailing: api.getThumbnail(widget.item.partImage),
        onTap: () async {
          showLoadingOverlay(context);
          var part = await InvenTreePart().get(widget.item.partId);
          hideLoadingOverlay();

          if (part is InvenTreePart) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
          }
        }
      )
    );

    // Available quantity
    tiles.add(
      ListTile(
        title: Text(L10().availableStock),
        leading: FaIcon(FontAwesomeIcons.boxesStacked),
        trailing: Text(simpleNumberString(widget.item.availableStock))
      )
    );

    // Allocated quantity
    tiles.add(
      ListTile(
        leading: FaIcon(FontAwesomeIcons.clipboardCheck),
        title: Text(L10().allocated),
        subtitle: ProgressBar(widget.item.allocatedRatio),
        trailing: Text(
          widget.item.allocatedString,
          style: TextStyle(
            color: widget.item.isAllocated ? COLOR_SUCCESS : COLOR_WARNING
          )
        )
      )
    );

    // Shipped quantity
    tiles.add(
      ListTile(
        title: Text(L10().shipped),
        subtitle: ProgressBar(widget.item.progressRatio),
        trailing: Text(
          widget.item.progressString,
          style: TextStyle(
            color: widget.item.isComplete ? COLOR_SUCCESS : COLOR_WARNING
          ),
        ),
        leading: FaIcon(FontAwesomeIcons.truck)
      )
    );

    // Reference
    if (widget.item.reference.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().reference),
          subtitle: Text(widget.item.reference),
          leading: FaIcon(FontAwesomeIcons.hashtag)
        )
      );
    }

    // Note
    if (widget.item.notes.isNotEmpty) {
      tiles.add(
          ListTile(
            title: Text(L10().notes),
            subtitle: Text(widget.item.notes),
            leading: FaIcon(FontAwesomeIcons.noteSticky),
          )
      );
    }

    // External link
    if (widget.item.link.isNotEmpty) {
      tiles.add(
          ListTile(
            title: Text(L10().link),
            subtitle: Text(widget.item.link),
            leading: FaIcon(FontAwesomeIcons.link, color: COLOR_ACTION),
            onTap: () async {
              await openLink(widget.item.link);
            },
          )
      );
    }

    return tiles;
  }
}