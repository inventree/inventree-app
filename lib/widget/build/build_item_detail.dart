import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
// Will use L10 later for internationalization
// import "package:inventree/l10.dart";

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
  String getAppBarTitle() => "Allocated Item"; // Will use L10().allocatedItem later

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    actions.add(
      IconButton(
        icon: const Icon(TablerIcons.edit),
        tooltip: "Edit Allocation", // Will use L10().editAllocation later
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
        label: "Unallocate", // Will use L10().unallocate later
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

    widget.item.editForm(
      context,
      "Edit Allocation", // Will use L10().editAllocation later
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(
          "Allocation updated",
          success: true,
        ); // Will use L10().allocationUpdated later
      },
    );
  }

  // Deallocate this stock item
  Future<void> _unallocateStock(BuildContext context) async {
    confirmationDialog(
      "Unallocate Stock", // Will use L10().unallocateStock later
      "Are you sure you want to unallocate this stock item?", // Will use L10().unallocateStockConfirm later
      icon: TablerIcons.minus,
      color: Colors.red,
      acceptText: "Unallocate", // Will use L10().unallocate later
      onAccept: () async {
        widget.item.delete().then((result) {
          if (result) {
            showSnackIcon(
              "Stock unallocated",
              success: true,
            ); // Will use L10().stockUnallocated later
            Navigator.pop(context);
          } else {
            showSnackIcon(
              "Failed to unallocate stock",
            ); // Will use L10().stockUnallocateFailed later
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
          title: const Text("Stock Item"), // Will use L10().stockItem later
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
          title: const Text("Location"), // Will use L10().location later
          subtitle: Text(
            widget.item.locationName.isNotEmpty
                ? widget.item.locationPath
                : "No location",
          ),
          leading: const Icon(TablerIcons.map_pin),
        ),
      );

      // Serial number if available
      if (widget.item.serialNumber.isNotEmpty) {
        tiles.add(
          ListTile(
            title: const Text(
              "Serial Number",
            ), // Will use L10().serialNumber later
            subtitle: Text(widget.item.serialNumber),
            leading: const Icon(TablerIcons.hash),
          ),
        );
      }

      // Batch code if available
      if (widget.item.batchCode.isNotEmpty) {
        tiles.add(
          ListTile(
            title: const Text("Batch Code"), // Will use L10().batchCode later
            subtitle: Text(widget.item.batchCode),
            leading: const Icon(TablerIcons.barcode),
          ),
        );
      }
    }

    // Quantity allocated
    tiles.add(
      ListTile(
        title: const Text(
          "Quantity Allocated",
        ), // Will use L10().quantityAllocated later
        subtitle: Text(widget.item.quantity.toString()),
        leading: const Icon(TablerIcons.list),
      ),
    );

    // Install into (if specified)
    if (widget.item.installIntoId > 0) {
      tiles.add(
        ListTile(
          title: const Text("Install Into"), // Will use L10().installInto later
          subtitle: const Text("View stock item"),
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
