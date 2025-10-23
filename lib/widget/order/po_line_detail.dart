import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/widget/link_icon.dart";

import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

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

  InvenTreeStockLocation? destination;

  @override
  String getAppBarTitle() => L10().lineItem;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.item.canEdit) {
      actions.add(
        IconButton(
          icon: Icon(TablerIcons.edit),
          onPressed: () {
            _editLineItem(context);
          },
        ),
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
            child: Icon(TablerIcons.transition_right, color: Colors.blue),
            label: L10().receiveItem,
            onTap: () async {
              receiveLineItem(context);
            },
          ),
        );
      }
    }

    return buttons;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.item.reload();

    if (widget.item.destinationId > 0) {
      InvenTreeStockLocation().get(widget.item.destinationId).then((
        InvenTreeModel? loc,
      ) {
        if (mounted) {
          if (loc != null && loc is InvenTreeStockLocation) {
            setState(() {
              destination = loc;
            });
          } else {
            setState(() {
              destination = null;
            });
          }
        }
      });
    } else {
      if (mounted) {
        setState(() {
          destination = null;
        });
      }
    }
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
      },
    );
  }

  // Launch a form to 'receive' this line item
  Future<void> receiveLineItem(BuildContext context) async {
    widget.item.receive(
      context,
      onSuccess: () => {
        showSnackIcon(L10().receivedItem, success: true),
        refresh(context),
      },
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
        leading: Icon(TablerIcons.box, color: COLOR_ACTION),
        trailing: LinkIcon(image: api.getThumbnail(widget.item.partImage)),
        onTap: () async {
          showLoadingOverlay();
          var part = await InvenTreePart().get(widget.item.partId);
          hideLoadingOverlay();

          if (part is InvenTreePart) {
            part.goToDetailPage(context);
          }
        },
      ),
    );

    // Reference to the supplier part
    tiles.add(
      ListTile(
        title: Text(L10().supplierPart),
        subtitle: Text(widget.item.SKU),
        leading: Icon(TablerIcons.building, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () async {
          showLoadingOverlay();
          var part = await InvenTreeSupplierPart().get(
            widget.item.supplierPartId,
          );
          hideLoadingOverlay();

          if (part is InvenTreeSupplierPart) {
            part.goToDetailPage(context);
          }
        },
      ),
    );

    // Destination
    if (destination != null) {
      tiles.add(
        ListTile(
          title: Text(L10().destination),
          subtitle: Text(destination!.name),
          leading: Icon(TablerIcons.map_pin, color: COLOR_ACTION),
          onTap: () => {destination!.goToDetailPage(context)},
        ),
      );
    }

    // Received quantity
    tiles.add(
      ListTile(
        title: Text(L10().received),
        subtitle: ProgressBar(widget.item.progressRatio),
        trailing: LargeText(
          widget.item.progressString,
          color: widget.item.isComplete ? COLOR_SUCCESS : COLOR_WARNING,
        ),
        leading: Icon(TablerIcons.progress),
      ),
    );

    // Reference
    if (widget.item.reference.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().reference),
          subtitle: Text(widget.item.reference),
          leading: Icon(TablerIcons.hash),
        ),
      );
    }

    // Pricing information
    tiles.add(
      ListTile(
        title: Text(L10().unitPrice),
        leading: Icon(TablerIcons.currency_dollar),
        trailing: LargeText(
          renderCurrency(
            widget.item.purchasePrice,
            widget.item.purchasePriceCurrency,
          ),
        ),
      ),
    );

    // Note
    if (widget.item.notes.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().notes),
          subtitle: Text(widget.item.notes),
          leading: Icon(TablerIcons.note),
        ),
      );
    }

    // External link
    if (widget.item.hasLink) {
      tiles.add(
        ListTile(
          title: Text(L10().link),
          subtitle: Text(widget.item.link),
          leading: Icon(TablerIcons.link, color: COLOR_ACTION),
          onTap: () async {
            await openLink(widget.item.link);
          },
        ),
      );
    }

    return tiles;
  }
}
