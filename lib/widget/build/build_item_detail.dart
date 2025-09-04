import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/dialogs.dart";

/*
 * Widget for displaying detail view of a single BuildItem (stock allocation)
*/
class BuildItemDetailWidget extends StatefulWidget {
  const BuildItemDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeBuildItem item;

  @override
  _BuildItemDetailWidgetState createState() => _BuildItemDetailWidgetState();
}

/*
 * State for the BuildItemDetailWidget
 */
class _BuildItemDetailWidgetState
    extends RefreshableState<BuildItemDetailWidget> {
  _BuildItemDetailWidgetState();

  @override
  String getAppBarTitle() => L10().allocatedItem;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    actions.add(
      IconButton(
        icon: const Icon(TablerIcons.edit),
        tooltip: L10().allocationEdit,
        onPressed: () {
          _editAllocation(context);
        },
      ),
    );

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> buttons = [];

    // Unallocate button
    buttons.add(
      SpeedDialChild(
        child: const Icon(TablerIcons.minus, color: Colors.red),
        label: L10().unallocate,
        onTap: () async {
          _unallocateStock(context);
        },
      ),
    );

    return buttons;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.item.reload();
  }

  // Edit this allocation
  Future<void> _editAllocation(BuildContext context) async {
    var fields = widget.item.formFields();
    
    fields["stock_item"]?["hidden"] = true;

    widget.item.editForm(
      context,
      L10().allocationEdit,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(
          L10().itemUpdated,
          success: true,
        );
      },
    );
  }

  // Deallocate this stock item
  Future<void> _unallocateStock(BuildContext context) async {
    confirmationDialog(
      L10().unallocateStock,
      L10().unallocateStockConfirm,
      icon: TablerIcons.minus,
      color: Colors.red,
      acceptText: L10().unallocate,
      onAccept: () async {
        widget.item.delete().then((result) {
          if (result) {
            showSnackIcon(
              L10().stockItemUpdated,
              success: true,
            );
            Navigator.pop(context);
          } else {
            showSnackIcon(L10().error);
          }
        });
      },
    );
  }

  // Go to stock item detail page
  Future<void> _viewStockItem(BuildContext context) async {
    if (widget.item.stockItem != null) {
      widget.item.stockItem!.goToDetailPage(context);
    }
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Stock item information
    if (widget.item.stockItem != null) {
      tiles.add(
        ListTile(
          title: Text(L10().stockItem),
          subtitle: Text(widget.item.stockItem!.partName),
          leading: widget.item.stockItem!.partImage.isNotEmpty
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: InvenTreeAPI().getThumbnail(
                    widget.item.stockItem!.partImage,
                  ),
                )
              : Icon(TablerIcons.box, color: COLOR_ACTION),
          trailing: const Icon(TablerIcons.chevron_right),
          onTap: () {
            _viewStockItem(context);
          },
        ),
      );

      // Location information
      tiles.add(
        ListTile(
          title: Text(L10().stockLocation),
          subtitle: Text(
            widget.item.locationName.isNotEmpty
                ? widget.item.locationPath
                : L10().locationNotSet
          ),
          leading: const Icon(TablerIcons.map_pin),
        ),
      );

      // Serial number if available
      if (widget.item.serialNumber.isNotEmpty) {
        tiles.add(
          ListTile(
            title: Text(L10().serialNumber),
            subtitle: Text(widget.item.serialNumber),
            leading: const Icon(TablerIcons.hash),
          ),
        );
      }

      // Batch code if available
      if (widget.item.batchCode.isNotEmpty) {
        tiles.add(
          ListTile(
            title: Text(L10().batchCode),
            subtitle: Text(widget.item.batchCode),
            leading: const Icon(TablerIcons.barcode),
          ),
        );
      }
    }

    // Quantity allocated
    tiles.add(
      ListTile(
        title: Text(L10().quantity),
        subtitle: Text(widget.item.quantity.toString()),
        leading: const Icon(TablerIcons.list),
      ),
    );

    // Install into (if specified)
    if (widget.item.installIntoId > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().buildOutput),
          subtitle: Text(L10().viewDetails),
          leading: const Icon(TablerIcons.arrow_right),
          trailing: const Icon(TablerIcons.chevron_right),
          onTap: () async {
            showLoadingOverlay();
            var stockItem = await InvenTreeStockItem().get(
              widget.item.installIntoId,
            );
            hideLoadingOverlay();

            if (stockItem is InvenTreeStockItem) {
              stockItem.goToDetailPage(context);
            }
          },
        ),
      );
    }

    return tiles;
  }
}
