import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/helpers.dart";

import "package:inventree/l10.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

import "package:inventree/inventree/orders.dart";

class ExtraLineDetailWidget extends StatefulWidget {
  const ExtraLineDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeExtraLineItem item;

  @override
  _ExtraLineDetailWidgetState createState() => _ExtraLineDetailWidgetState();
}

class _ExtraLineDetailWidgetState
    extends RefreshableState<ExtraLineDetailWidget> {
  _ExtraLineDetailWidgetState();

  @override
  String getAppBarTitle() => L10().extraLineItem;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.item.canEdit) {
      actions.add(IconButton(
          icon: Icon(TablerIcons.edit),
          onPressed: () {
            _editLineItem(context);
          }));
    }

    return actions;
  }

  // Function to request data for this page
  @override
  Future<void> request(BuildContext context) async {
    await widget.item.reload();
  }

  // Callback to edit this line item
  Future<void> _editLineItem(BuildContext context) async {
    var fields = widget.item.formFields();

    widget.item.editForm(context, L10().editLineItem, fields: fields,
        onSuccess: (data) async {
      refresh(context);
      showSnackIcon(L10().lineItemUpdated, success: true);
    });
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    tiles.add(ListTile(
      title: Text(L10().reference),
      trailing: Text(widget.item.reference),
    ));

    tiles.add(ListTile(
      title: Text(L10().description),
      trailing: Text(widget.item.description),
    ));

    tiles.add(ListTile(
      title: Text(L10().quantity),
      trailing: Text(widget.item.quantity.toString()),
    ));

    tiles.add(ListTile(
        title: Text(L10().unitPrice),
        trailing: Text(
            renderCurrency(widget.item.price, widget.item.priceCurrency))));

    if (widget.item.notes.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().notes),
        subtitle: Text(widget.item.notes),
      ));
    }

    return tiles;
  }
}
