import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/helpers.dart";

import "package:inventree/l10.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";


class POExtraLineDetailWidget extends StatefulWidget {
  const POExtraLineDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreePOExtraLineItem item;

  @override
  _POExtraLineDetailWidgetState createState() => _POExtraLineDetailWidgetState();
}

class _POExtraLineDetailWidgetState extends RefreshableState<POExtraLineDetailWidget> {

  _POExtraLineDetailWidgetState();

  @override
  String getAppBarTitle() => L10().extraLineItem;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.item.canEdit) {
      actions.add(
        IconButton(
          icon: Icon(TablerIcons.edit),
          onPressed: () {
            _editLineItem(context);
          }
        )
      );
    }

    return actions;
  }

  // Function to request data for this page
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

    tiles.add(
        ListTile(
          title: Text(L10().reference),
          trailing: Text(widget.item.reference),
        )
    );

    tiles.add(
        ListTile(
          title: Text(L10().description),
          trailing: Text(widget.item.description),
        )
    );

    tiles.add(
      ListTile(
        title: Text(L10().quantity),
        trailing: Text(widget.item.quantity.toString()),
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().unitPrice),
        trailing: Text(
          renderCurrency(widget.item.price, widget.item.priceCurrency)
        )
      )
    );

    if (widget.item.notes.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().notes),
          subtitle: Text(widget.item.notes),
        )
      );
    }

    return tiles;
  }
}