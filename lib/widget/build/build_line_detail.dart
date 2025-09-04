import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
// Will use L10 later for internationalization
// import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/build.dart";

import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Widget for displaying detail view of a single BuildOrderLineItem
*/
class BuildLineDetailWidget extends StatefulWidget {
  const BuildLineDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeBuildLine item;

  @override
  _BuildLineDetailWidgetState createState() => _BuildLineDetailWidgetState();
}

/*
 * State for the BuildLineDetailWidget
 */
class _BuildLineDetailWidgetState
    extends RefreshableState<BuildLineDetailWidget> {
  _BuildLineDetailWidgetState();

  @override
  String getAppBarTitle() => "Line Item"; // Will use L10().lineItem later

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.item.canEdit) {
      actions.add(
        IconButton(
          icon: const Icon(TablerIcons.edit),
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
    // Currently, no action buttons are needed as allocation/deallocation
    // is done at the build order level instead of individual line level
    return [];
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
      "Edit Line Item", // Will use L10().editLineItem later
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(
          "Line item updated",
          success: true,
        ); // Will use L10().lineItemUpdated later
      },
    );
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Reference to the part
    tiles.add(
      ListTile(
        title: const Text("Part"), // Will use L10().part later
        subtitle: Text(widget.item.partName),
        leading:
            widget.item.part != null && widget.item.part!.thumbnail.isNotEmpty
            ? SizedBox(
                width: 32,
                height: 32,
                child: InvenTreeAPI().getThumbnail(widget.item.part!.thumbnail),
              )
            : Icon(TablerIcons.box, color: COLOR_ACTION),
        trailing: const Icon(TablerIcons.chevron_right),
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

    // Required quantity
    tiles.add(
      ListTile(
        title: const Text(
          "Required Quantity",
        ), // Will use L10().requiredQuantity later
        subtitle: Text(widget.item.requiredQuantity.toString()),
        leading: const Icon(TablerIcons.list),
      ),
    );

    // Allocated quantity
    tiles.add(
      ListTile(
        title: const Text("Allocated"), // Will use L10().allocated later
        subtitle: ProgressBar(
          widget.item.allocatedQuantity / widget.item.requiredQuantity,
        ),
        trailing: Text(
          "${widget.item.allocatedQuantity.toInt()} / ${widget.item.requiredQuantity.toInt()}",
          style: TextStyle(
            color: widget.item.isFullyAllocated ? COLOR_SUCCESS : COLOR_WARNING,
          ),
        ),
        leading: const Icon(TablerIcons.progress),
      ),
    );

    // Reference
    if (widget.item.reference.isNotEmpty) {
      tiles.add(
        ListTile(
          title: const Text("Reference"), // Will use L10().reference later
          subtitle: Text(widget.item.reference),
          leading: const Icon(TablerIcons.hash),
        ),
      );
    }

    // Notes
    if (widget.item.notes.isNotEmpty) {
      tiles.add(
        ListTile(
          title: const Text("Notes"), // Will use L10().notes later
          subtitle: Text(widget.item.notes),
          leading: const Icon(TablerIcons.note),
        ),
      );
    }

    return tiles;
  }
}
