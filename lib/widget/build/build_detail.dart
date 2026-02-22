import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/attachment_widget.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/build/build_line_list.dart";
import "package:inventree/widget/build/build_item_list.dart";
import "package:inventree/widget/build/build_output_list.dart";

/*
 * Widget for viewing a single BuildOrder instance
 */
class BuildOrderDetailWidget extends StatefulWidget {
  const BuildOrderDetailWidget(this.order, {Key? key}) : super(key: key);

  final InvenTreeBuildOrder order;

  @override
  _BuildOrderDetailState createState() => _BuildOrderDetailState();
}

class _BuildOrderDetailState extends RefreshableState<BuildOrderDetailWidget> {
  _BuildOrderDetailState();

  // Track state of the build order
  int allocatedLineCount = 0;
  int totalLineCount = 0;
  int outputCount = 0;
  int attachmentCount = 0;

  bool showCameraShortcut = true;

  @override
  String getAppBarTitle() {
    String title = L10().buildOrder;

    if (widget.order.reference.isNotEmpty) {
      title += " - ${widget.order.reference}";
    }

    return title;
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.order.canEdit) {
      actions.add(
        IconButton(
          icon: const Icon(TablerIcons.edit),
          tooltip: L10().buildOrderEdit,
          onPressed: () {
            editOrder(context);
          },
        ),
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    // Image upload shortcut
    if (showCameraShortcut && widget.order.canEdit) {
      actions.add(
        SpeedDialChild(
          child: const Icon(TablerIcons.camera, color: Colors.blue),
          label: L10().takePicture,
          onTap: () async {
            _uploadImage(context);
          },
        ),
      );
    }

    // Add actions based on current build order state
    if (widget.order.canEdit) {
      // Issue action (for pending build orders)
      if (widget.order.canIssue) {
        actions.add(
          SpeedDialChild(
            child: const Icon(TablerIcons.send, color: Colors.blue),
            label: L10().issueOrder,
            onTap: () async {
              _issueOrder(context);
            },
          ),
        );
      }

      // Complete action (for in-progress build orders with outputs)
      if (widget.order.canCompleteOrder) {
        actions.add(
          SpeedDialChild(
            child: const Icon(TablerIcons.check, color: Colors.green),
            label: L10().completeOrder,
            onTap: () async {
              _completeOrder(context);
            },
          ),
        );
      }

      // Hold action
      if (widget.order.canHold) {
        actions.add(
          SpeedDialChild(
            child: const Icon(TablerIcons.player_pause, color: Colors.orange),
            label: L10().holdOrder,
            onTap: () async {
              _holdOrder(context);
            },
          ),
        );
      }

      // Auto-allocate action (for in-progress build orders)
      if (widget.order.isInProgress) {
        actions.add(
          SpeedDialChild(
            child: const Icon(
              TablerIcons.arrow_autofit_down,
              color: Colors.purple,
            ),
            label: L10().allocateAuto,
            onTap: () async {
              _autoAllocate(context);
            },
          ),
        );
      }

      // Unallocate action (if there are allocated items)
      if (widget.order.isInProgress &&
          widget.order.allocatedLineItemCount > 0) {
        actions.add(
          SpeedDialChild(
            child: const Icon(TablerIcons.arrow_autofit_up, color: Colors.red),
            label: L10().unallocateStock,
            onTap: () async {
              _unallocateAll(context);
            },
          ),
        );
      }

      // Cancel action
      if (widget.order.canCancel) {
        actions.add(
          SpeedDialChild(
            child: const Icon(TablerIcons.circle_x, color: Colors.red),
            label: L10().cancelOrder,
            onTap: () async {
              _cancelOrder(context);
            },
          ),
        );
      }
    }

    return actions;
  }

  /// Upload an image against the current BuildOrder
  Future<void> _uploadImage(BuildContext context) async {
    // Implement image upload when attachment classes are created
    // Placeholder for now
  }

  /// Issue this build order
  Future<void> _issueOrder(BuildContext context) async {
    confirmationDialog(
      L10().issueOrder,
      L10().issueOrderConfirm,
      icon: TablerIcons.send,
      color: Colors.blue,
      acceptText: L10().issue,
      onAccept: () async {
        widget.order.issue().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Complete this build order
  Future<void> _completeOrder(BuildContext context) async {
    confirmationDialog(
      L10().completeOrder,
      L10().completeOrderConfirm,
      icon: TablerIcons.check,
      color: Colors.green,
      acceptText: L10().complete,
      onAccept: () async {
        widget.order.completeOrder().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Hold this build order
  Future<void> _holdOrder(BuildContext context) async {
    confirmationDialog(
      L10().holdOrder,
      L10().holdOrderConfirm,
      icon: TablerIcons.player_pause,
      color: Colors.orange,
      acceptText: L10().hold,
      onAccept: () async {
        widget.order.hold().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Cancel this build order
  Future<void> _cancelOrder(BuildContext context) async {
    confirmationDialog(
      L10().cancelOrder,
      L10().cancelOrderConfirm,
      icon: TablerIcons.circle_x,
      color: Colors.red,
      acceptText: L10().cancel,
      onAccept: () async {
        widget.order.cancel().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Auto allocate stock items for this build order
  Future<void> _autoAllocate(BuildContext context) async {
    confirmationDialog(
      L10().allocateAuto,
      L10().allocateAutoDetail,
      icon: TablerIcons.arrow_autofit_down,
      color: Colors.purple,
      acceptText: L10().allocate,
      onAccept: () async {
        widget.order.autoAllocate().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Unallocate all stock from this build order
  Future<void> _unallocateAll(BuildContext context) async {
    confirmationDialog(
      L10().unallocateStock,
      L10().buildOrderUnallocateDetail,
      icon: TablerIcons.trash,
      color: Colors.orange,
      acceptText: L10().unallocate,
      onAccept: () async {
        widget.order.unallocateAll().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    // Build orders don't have barcode functionality yet
    return [];
  }

  @override
  Future<void> request(BuildContext context) async {
    super.request(context);

    // Refresh the BuildOrder instance
    widget.order.reload().then(
      (response) => {
        if (mounted) {setState(() {})},
      },
    );
  }

  /// Edit this build order
  Future<void> editOrder(BuildContext context) async {
    if (!widget.order.canEdit) {
      return;
    }

    var fields = widget.order.formFields();

    // Cannot edit part field from here
    fields.remove("part");

    widget.order.editForm(
      context,
      L10().buildOrderEdit,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
      },
    );
  }

  /// Header tile for the build order
  Widget headerTile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.order.reference,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              BuildOrderStatus.getStatusText(widget.order.status),
              style: TextStyle(
                color: BuildOrderStatus.getStatusColor(widget.order.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the list of order detail tiles
  List<Widget> orderTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Header tile
    tiles.add(headerTile(context));

    // Part information
    if (widget.order.partDetail != null) {
      InvenTreePart part = widget.order.partDetail!;

      tiles.add(
        ListTile(
          title: Text(part.name),
          subtitle: Text(part.description),
          leading: part.thumbnail.isNotEmpty
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: InvenTreeAPI().getThumbnail(part.thumbnail),
                )
              : const Icon(TablerIcons.box, color: Colors.blue),
          onTap: () {
            part.goToDetailPage(context);
          },
        ),
      );
    }

    // Build quantities
    tiles.add(
      ListTile(
        title: Text(L10().quantity),
        leading: const Icon(TablerIcons.box),
        trailing: Text(
          "${widget.order.completed.toInt()} / ${widget.order.quantity.toInt()}",
        ),
      ),
    );

    // Progress bar
    Color progressColor = Colors.blue;

    if (widget.order.isComplete) {
      progressColor = Colors.green;
    } else if (widget.order.targetDate.isNotEmpty &&
        DateTime.tryParse(widget.order.targetDate) != null &&
        DateTime.tryParse(widget.order.targetDate)!.isBefore(DateTime.now())) {
      progressColor = Colors.red;
    }

    tiles.add(
      ListTile(
        title: LinearProgressIndicator(
          value: widget.order.progressPercent / 100.0,
          color: progressColor,
          backgroundColor: const Color(0xFFEEEEEE),
        ),
        leading: const Icon(TablerIcons.chart_bar),
        trailing: Text(
          "${widget.order.progressPercent.toStringAsFixed(1)}%",
          style: TextStyle(color: progressColor, fontWeight: FontWeight.bold),
        ),
      ),
    );

    // Line items tile
    Color lineColor = Colors.red;
    if (widget.order.areAllLinesAllocated) {
      lineColor = Colors.green;
    } else if (widget.order.allocatedLineItemCount > 0) {
      lineColor = Colors.orange;
    }

    tiles.add(
      ListTile(
        title: Text(L10().requiredParts),
        subtitle: LinearProgressIndicator(
          value: widget.order.lineItemCount > 0
              ? widget.order.allocatedLineItemCount / widget.order.lineItemCount
              : 0,
          color: lineColor,
        ),
        leading: const Icon(TablerIcons.clipboard_check),
        trailing: Text(
          "${widget.order.allocatedLineItemCount} / ${widget.order.lineItemCount}",
          style: TextStyle(color: lineColor),
        ),
      ),
    );

    // Output items
    tiles.add(
      ListTile(
        title: Text(L10().allocatedStock),
        leading: Icon(TablerIcons.box_model_2, color: COLOR_ACTION),
        trailing: LinkIcon(text: widget.order.outputCount.toString()),
        onTap: () => {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaginatedBuildItemWidget(widget.order),
            ),
          ),
        },
      ),
    );

    // Dates
    if (widget.order.creationDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().creationDate),
          trailing: Text(widget.order.creationDate),
          leading: const Icon(TablerIcons.calendar),
        ),
      );
    }

    if (widget.order.startDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().startDate),
          trailing: Text(widget.order.startDate),
          leading: const Icon(TablerIcons.calendar),
        ),
      );
    }

    if (widget.order.targetDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().targetDate),
          trailing: Text(widget.order.targetDate),
          leading: const Icon(TablerIcons.calendar),
        ),
      );
    }

    if (widget.order.completionDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().completionDate),
          trailing: Text(widget.order.completionDate),
          leading: const Icon(TablerIcons.calendar),
        ),
      );
    }

    // Notes tile
    tiles.add(
      ListTile(
        title: Text(L10().notes),
        leading: Icon(TablerIcons.notes, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesWidget(widget.order)),
          );
        },
      ),
    );

    // Attachments tile
    ListTile? attachmentTile = ShowAttachmentsItem(
      context,
      InvenTreeBuildOrder.MODEL_TYPE,
      widget.order.pk,
      widget.order.reference,
      attachmentCount,
      widget.order.canEdit,
    );

    if (attachmentTile != null) {
      tiles.add(attachmentTile);
    }

    return tiles;
  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    return [
      Tab(text: L10().details),
      Tab(text: L10().requiredParts),
      // Tab(text: L10().allocatedStock),
      Tab(text: L10().buildOutputs),
    ];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      ListView(children: orderTiles(context)),
      PaginatedBuildLineList({"build": widget.order.pk.toString()}),
      // PaginatedBuildItemList({"build": widget.order.pk.toString()}),
      PaginatedBuildOutputList({"build": widget.order.pk.toString()}),
    ];
  }
}
