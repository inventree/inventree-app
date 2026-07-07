import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api_form.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/transfer_order.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/order/transfer_order_line_list.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Widget for viewing a single TransferOrder instance
 */
class TransferOrderDetailWidget extends StatefulWidget {
  const TransferOrderDetailWidget(this.order, {Key? key}) : super(key: key);

  final InvenTreeTransferOrder order;

  @override
  _TransferOrderDetailState createState() => _TransferOrderDetailState();
}

class _TransferOrderDetailState
    extends RefreshableState<TransferOrderDetailWidget> {
  _TransferOrderDetailState();

  InvenTreeStockLocation? sourceLocation;
  InvenTreeStockLocation? destinationLocation;

  int completedLines = 0;

  @override
  String getAppBarTitle() {
    String title = L10().transferOrder;

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
          icon: Icon(TablerIcons.edit),
          tooltip: L10().transferOrderEdit,
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

    if (!widget.order.canEdit) {
      return actions;
    }

    if (widget.order.canIssue) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.send, color: COLOR_ACTION),
          label: L10().issueOrder,
          onTap: () async {
            _issueOrder(context);
          },
        ),
      );
    }

    if (widget.order.canCompleteOrder) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.circle_check, color: COLOR_SUCCESS),
          label: L10().completeOrder,
          onTap: () async {
            _completeOrder(context);
          },
        ),
      );
    }

    if (widget.order.canHold) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.player_pause, color: COLOR_WARNING),
          label: L10().holdOrder,
          onTap: () async {
            _holdOrder(context);
          },
        ),
      );
    }

    if (widget.order.canCancel) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.circle_x, color: COLOR_DANGER),
          label: L10().cancelOrder,
          onTap: () async {
            _cancelOrder(context);
          },
        ),
      );
    }

    return actions;
  }

  /// Issue this order
  Future<void> _issueOrder(BuildContext context) async {
    confirmationDialog(
      L10().issueOrder,
      L10().issueOrderConfirm,
      icon: TablerIcons.send,
      color: COLOR_ACTION,
      acceptText: L10().issue,
      onAccept: () async {
        widget.order.issue().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Complete this order
  Future<void> _completeOrder(BuildContext context) async {
    Map<String, Map<String, dynamic>> fields = {"accept_incomplete": {}};

    String url = "${widget.order.URL}${widget.order.pk}/complete/";

    launchApiForm(
      context,
      L10().completeOrder,
      url,
      fields,
      method: "POST",
      onSuccess: (data) async {
        refresh(context);
      },
    );
  }

  /// Place this order on hold
  Future<void> _holdOrder(BuildContext context) async {
    confirmationDialog(
      L10().holdOrder,
      L10().holdOrderConfirm,
      icon: TablerIcons.player_pause,
      color: COLOR_WARNING,
      acceptText: L10().hold,
      onAccept: () async {
        widget.order.hold().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Cancel this order
  Future<void> _cancelOrder(BuildContext context) async {
    confirmationDialog(
      L10().cancelOrder,
      L10().cancelOrderConfirm,
      icon: TablerIcons.circle_x,
      color: COLOR_DANGER,
      acceptText: L10().cancel,
      onAccept: () async {
        widget.order.cancel().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    // Transfer orders don't have barcode functionality yet
    return [];
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.order.reload();

    List<InvenTreeTransferOrderLineItem> lines = await widget.order
        .getLineItems();

    completedLines = 0;

    for (var line in lines) {
      if (line.isComplete) {
        completedLines += 1;
      }
    }

    if (widget.order.sourceLocationId != null) {
      InvenTreeStockLocation().get(widget.order.sourceLocationId!).then((
        InvenTreeModel? loc,
      ) {
        if (mounted) {
          setState(() {
            sourceLocation = loc is InvenTreeStockLocation ? loc : null;
          });
        }
      });
    } else if (mounted) {
      setState(() {
        sourceLocation = null;
      });
    }

    if (widget.order.destinationId != null) {
      InvenTreeStockLocation().get(widget.order.destinationId!).then((
        InvenTreeModel? loc,
      ) {
        if (mounted) {
          setState(() {
            destinationLocation = loc is InvenTreeStockLocation ? loc : null;
          });
        }
      });
    } else if (mounted) {
      setState(() {
        destinationLocation = null;
      });
    }
  }

  /// Edit the currently displayed TransferOrder
  Future<void> editOrder(BuildContext context) async {
    var fields = widget.order.formFields();

    widget.order.editForm(
      context,
      L10().transferOrderEdit,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().transferOrderUpdated, success: true);
      },
    );
  }

  Widget headerTile(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.order.reference),
        subtitle: Text(widget.order.description),
        trailing: LargeText(
          TransferOrderStatus.getStatusText(widget.order.status),
          color: TransferOrderStatus.getStatusColor(widget.order.status),
        ),
      ),
    );
  }

  List<Widget> orderTiles(BuildContext context) {
    List<Widget> tiles = [];

    tiles.add(headerTile(context));

    if (showPk) {
      tiles.add(pkTile(widget.order.pk));
    }

    if (widget.order.hasProjectCode) {
      tiles.add(
        ListTile(
          title: Text(L10().projectCode),
          subtitle: Text(
            "${widget.order.projectCode} - ${widget.order.projectCodeDescription}",
          ),
          leading: Icon(TablerIcons.list),
        ),
      );
    }

    if (sourceLocation != null) {
      tiles.add(
        ListTile(
          title: Text(L10().sourceLocation),
          subtitle: Text(sourceLocation!.pathstring),
          leading: Icon(TablerIcons.map_pin, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () => sourceLocation!.goToDetailPage(context),
        ),
      );
    }

    if (destinationLocation != null) {
      tiles.add(
        ListTile(
          title: Text(L10().destination),
          subtitle: Text(destinationLocation!.pathstring),
          leading: Icon(TablerIcons.map_pin, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () => destinationLocation!.goToDetailPage(context),
        ),
      );
    }

    if (widget.order.consume) {
      tiles.add(
        ListTile(
          title: Text(L10().consume),
          subtitle: Text(L10().consumeDetail),
          leading: Icon(TablerIcons.flame, color: COLOR_WARNING),
        ),
      );
    }

    Color lineColor = completedLines < widget.order.lineItemCount
        ? COLOR_WARNING
        : COLOR_SUCCESS;

    tiles.add(
      ListTile(
        title: Text(L10().lineItems),
        subtitle: ProgressBar(
          completedLines.toDouble(),
          maximum: widget.order.lineItemCount.toDouble(),
        ),
        leading: Icon(TablerIcons.clipboard_check),
        trailing: LargeText(
          "${completedLines} / ${widget.order.lineItemCount}",
          color: lineColor,
        ),
      ),
    );

    if (widget.order.creationDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().creationDate),
          trailing: LargeText(widget.order.creationDate),
          leading: Icon(TablerIcons.calendar),
        ),
      );
    }

    if (widget.order.startDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().startDate),
          trailing: LargeText(widget.order.startDate),
          leading: Icon(TablerIcons.calendar),
        ),
      );
    }

    if (widget.order.targetDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().targetDate),
          trailing: LargeText(widget.order.targetDate),
          leading: Icon(TablerIcons.calendar),
        ),
      );
    }

    if (widget.order.completionDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().completionDate),
          trailing: LargeText(widget.order.completionDate),
          leading: Icon(TablerIcons.calendar),
        ),
      );
    }

    if (widget.order.responsibleName.isNotEmpty &&
        widget.order.responsibleLabel.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().responsible),
          leading: Icon(
            widget.order.responsibleLabel == "group"
                ? TablerIcons.users
                : TablerIcons.user,
          ),
          trailing: LargeText(widget.order.responsibleName),
        ),
      );
    }

    tiles.add(
      ListTile(
        title: Text(L10().notes),
        leading: Icon(TablerIcons.note, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesWidget(widget.order)),
          );
        },
      ),
    );

    return tiles;
  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    return [Tab(text: L10().details), Tab(text: L10().parts)];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      ListView(children: orderTiles(context)),
      PaginatedTransferOrderLineList({"order": widget.order.pk.toString()}),
    ];
  }
}
