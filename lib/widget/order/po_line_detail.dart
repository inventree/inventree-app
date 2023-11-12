import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api_form.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/part/part_detail.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/company/supplier_part_detail.dart";

/*
 * Widget for displaying detail view of a single PurchaseOrderLineItem
*/
class POLineDetailWidget extends StatefulWidget {

  const POLineDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreePOLineItem item;

  @override
  _POLineDetailWidgetState createState() => _POLineDetailWidgetState();

}


/*
 * State for the POLineDetailWidget
 */
class _POLineDetailWidgetState extends RefreshableState<POLineDetailWidget> {

  _POLineDetailWidgetState();

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
          },
        )
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> buttons = [];

    if (widget.item.canCreate) {
      // Receive items
      if (!widget.item.isComplete) {
        buttons.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.rightToBracket, color: Colors.blue),
            label: L10().receiveItem,
            onTap: () async {
              receiveLineItem(context);
            }
          )
        );
      }
    }

    return buttons;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.item.reload();
  }

  // Callback to edit this line item
  Future<void> _editLineItem(BuildContext context) async {
    var fields = widget.item.formFields();

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

    // Launch a form to 'receive' this line item
  Future<void> receiveLineItem(BuildContext context) async {

    // Construct fields to receive
    Map<String, dynamic> fields = {
      "line_item": {
        "parent": "items",
        "nested": true,
        "hidden": true,
        "value": widget.item.pk,
      },
      "quantity": {
        "parent": "items",
        "nested": true,
        "value": widget.item.outstanding,
      },
      "status": {
        "parent": "items",
        "nested": true,
      },
      "location": {},
      "batch_code": {
        "parent": "items",
        "nested": true,
      },
      "barcode": {
        "parent": "items",
        "nested": true,
        "type": "barcode",
        "label": L10().barcodeAssign,
        "required": false,
      }
    };

    showLoadingOverlay(context);
    var order = await InvenTreePurchaseOrder().get(widget.item.orderId);
    hideLoadingOverlay();

    if (order is InvenTreePurchaseOrder) {
    launchApiForm(
      context,
      L10().receiveItem,
      order.receive_url,
      fields,
      method: "POST",
      icon: FontAwesomeIcons.rightToBracket,
      onSuccess: (data) async {
        showSnackIcon(L10().receivedItem, success: true);
        refresh(context);
      }
    );
    } else {
      showSnackIcon(L10().error);
      return;
    }
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Reference to the part
    tiles.add(
      ListTile(
        title: Text(L10().internalPart),
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
        },
      )
    );

    // Reference to the supplier part
    tiles.add(
      ListTile(
        title: Text(L10().supplierPart),
        subtitle: Text(widget.item.SKU),
        leading: FaIcon(FontAwesomeIcons.building, color: COLOR_ACTION),
        onTap: () async {
          showLoadingOverlay(context);
          var part = await InvenTreeSupplierPart().get(widget.item.supplierPartId);
          hideLoadingOverlay();

          if (part is InvenTreeSupplierPart) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => SupplierPartDetailWidget(part)));
          }
        },
      )
    );

    // Received quantity
    tiles.add(
      ListTile(
        title: Text(L10().received),
        subtitle: ProgressBar(widget.item.progressRatio),
        trailing: Text(
            widget.item.progressString,
            style: TextStyle(
                color: widget.item.isComplete ? COLOR_SUCCESS: COLOR_WARNING
            )
        ),
        leading: FaIcon(FontAwesomeIcons.boxOpen),
      )
    );

    // Reference
    if (widget.item.reference.isNotEmpty) {
      tiles.add(
          ListTile(
            title: Text(L10().reference),
            subtitle: Text(widget.item.reference),
            leading: FaIcon(FontAwesomeIcons.hashtag),
          )
      );
    }

    // Pricing information
    tiles.add(
      ListTile(
        title: Text(L10().unitPrice),
        leading: FaIcon(FontAwesomeIcons.dollarSign),
        trailing: Text(
          renderCurrency(widget.item.purchasePrice, widget.item.purchasePriceCurrency)
        ),
      )
    );

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