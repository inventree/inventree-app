import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/part_detail.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/supplier_part_detail.dart";

/*
 * Widget for displaying detail view of a purchase order line item
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
          print("part id: ${widget.item.partId}");
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

    // Recevied
    tiles.add(
      ListTile(
        title: Text(L10().received),
        subtitle: Text(widget.item.received.toString()),
        trailing: Text(widget.item.progressString, style: TextStyle(color: widget.item.isComplete ? COLOR_SUCCESS: COLOR_WARNING)),
        leading: FaIcon(FontAwesomeIcons.boxOpen),
      )
    );

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