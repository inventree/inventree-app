import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/purchase_order.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/purchase_order.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/order/po_extra_line_list.dart";
import "package:inventree/widget/order/po_line_list.dart";

import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock/stock_list.dart";
import "package:inventree/preferences.dart";

/*
 * Widget for viewing a single PurchaseOrder instance
 */
class PurchaseOrderDetailWidget extends StatefulWidget {
  const PurchaseOrderDetailWidget(this.order, {Key? key}) : super(key: key);

  final InvenTreePurchaseOrder order;

  @override
  _PurchaseOrderDetailState createState() => _PurchaseOrderDetailState();
}

class _PurchaseOrderDetailState
    extends RefreshableState<PurchaseOrderDetailWidget> {
  _PurchaseOrderDetailState();

  List<InvenTreePOLineItem> lines = [];
  int extraLineCount = 0;

  InvenTreeStockLocation? destination;

  int completedLines = 0;
  int attachmentCount = 0;

  bool showCameraShortcut = true;
  bool supportProjectCodes = false;

  @override
  String getAppBarTitle() {
    String title = L10().purchaseOrder;

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
          tooltip: L10().purchaseOrderEdit,
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

    if (showCameraShortcut && widget.order.canEdit) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.camera, color: Colors.blue),
          label: L10().takePicture,
          onTap: () async {
            _uploadImage(context);
          },
        ),
      );
    }

    if (widget.order.canCreate) {
      if (widget.order.isPending) {
        actions.add(
          SpeedDialChild(
            child: Icon(TablerIcons.circle_plus, color: Colors.green),
            label: L10().lineItemAdd,
            onTap: () async {
              _addLineItem(context);
            },
          ),
        );

        actions.add(
          SpeedDialChild(
            child: Icon(TablerIcons.send, color: Colors.blue),
            label: L10().issueOrder,
            onTap: () async {
              _issueOrder(context);
            },
          ),
        );
      }

      if (widget.order.isOpen) {
        actions.add(
          SpeedDialChild(
            child: Icon(TablerIcons.circle_x, color: Colors.red),
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

  /// Add a new line item to this order
  Future<void> _addLineItem(BuildContext context) async {
    var fields = InvenTreePOLineItem().formFields();

    // Update part field definition
    fields["part"]?["hidden"] = false;
    fields["part"]?["filters"] = {"supplier": widget.order.supplierId};

    fields["order"]?["value"] = widget.order.pk;

    InvenTreePOLineItem().createForm(
      context,
      L10().lineItemAdd,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().lineItemUpdated, success: true);
      },
    );
  }

  /// Upload an image against the current PurchaseOrder
  Future<void> _uploadImage(BuildContext context) async {
    InvenTreePurchaseOrderAttachment()
        .uploadImage(widget.order.pk, prefix: widget.order.reference)
        .then((result) => refresh(context));
  }

  /// Issue this order
  Future<void> _issueOrder(BuildContext context) async {
    confirmationDialog(
      L10().issueOrder,
      "",
      icon: TablerIcons.send,
      color: Colors.blue,
      acceptText: L10().issue,
      onAccept: () async {
        widget.order.issueOrder().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  /// Cancel this order
  Future<void> _cancelOrder(BuildContext context) async {
    confirmationDialog(
      L10().cancelOrder,
      "",
      icon: TablerIcons.circle_x,
      color: Colors.red,
      acceptText: L10().cancel,
      onAccept: () async {
        widget.order.cancelOrder().then((dynamic) {
          refresh(context);
        });
      },
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (api.supportsBarcodePOReceiveEndpoint && widget.order.isPlaced) {
      actions.add(
        SpeedDialChild(
          child: Icon(Icons.barcode_reader),
          label: L10().scanReceivedParts,
          onTap: () async {
            scanBarcode(
              context,
              handler: POReceiveBarcodeHandler(purchaseOrder: widget.order),
            ).then((value) {
              refresh(context);
            });
          },
        ),
      );
    }

    if (widget.order.isPending && api.supportsBarcodePOAddLineEndpoint) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.circle_plus, color: COLOR_SUCCESS),
          label: L10().lineItemAdd,
          onTap: () async {
            scanBarcode(
              context,
              handler: POAllocateBarcodeHandler(purchaseOrder: widget.order),
            );
          },
        ),
      );
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.order.reload();

    await api.PurchaseOrderStatus.load();

    lines = await widget.order.getLineItems();

    showCameraShortcut = await InvenTreeSettingsManager().getBool(
      INV_PO_SHOW_CAMERA,
      true,
    );
    supportProjectCodes =
        api.supportsProjectCodes &&
        await api.getGlobalBooleanSetting(
          "PROJECT_CODES_ENABLED",
          backup: true,
        );

    completedLines = 0;

    for (var line in lines) {
      if (line.isComplete) {
        completedLines += 1;
      }
    }

    InvenTreePurchaseOrderAttachment().countAttachments(widget.order.pk).then((
      int value,
    ) {
      if (mounted) {
        setState(() {
          attachmentCount = value;
        });
      }
    });

    if (api.supportsPurchaseOrderDestination &&
        widget.order.destinationId > 0) {
      InvenTreeStockLocation().get(widget.order.destinationId).then((
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

    // Count number of "extra line items" against this order
    InvenTreePOExtraLineItem()
        .count(filters: {"order": widget.order.pk.toString()})
        .then((int value) {
          if (mounted) {
            setState(() {
              extraLineCount = value;
            });
          }
        });
  }

  // Edit the currently displayed PurchaseOrder
  Future<void> editOrder(BuildContext context) async {
    var fields = widget.order.formFields();

    // Cannot edit supplier field from here
    fields.remove("supplier");

    // Contact model not supported by server
    if (!api.supportsContactModel) {
      fields.remove("contact");
    }

    // ProjectCode model not supported by server
    if (!supportProjectCodes) {
      fields.remove("project_code");
    }

    widget.order.editForm(
      context,
      L10().purchaseOrderEdit,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().purchaseOrderUpdated, success: true);
      },
    );
  }

  Widget headerTile(BuildContext context) {
    InvenTreeCompany? supplier = widget.order.supplier;

    return Card(
      child: ListTile(
        title: Text(widget.order.reference),
        subtitle: Text(widget.order.description),
        leading: supplier == null ? null : api.getThumbnail(supplier.thumbnail),
        trailing: LargeText(
          api.PurchaseOrderStatus.label(widget.order.status),
          color: api.PurchaseOrderStatus.color(widget.order.status),
        ),
      ),
    );
  }

  List<Widget> orderTiles(BuildContext context) {
    List<Widget> tiles = [];

    InvenTreeCompany? supplier = widget.order.supplier;

    tiles.add(headerTile(context));

    if (supportProjectCodes && widget.order.hasProjectCode) {
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

    if (supplier != null) {
      tiles.add(
        ListTile(
          title: Text(L10().supplier),
          subtitle: Text(supplier.name),
          leading: Icon(TablerIcons.building, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () {
            supplier.goToDetailPage(context);
          },
        ),
      );
    }

    if (widget.order.supplierReference.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().supplierReference),
          subtitle: Text(widget.order.supplierReference),
          leading: Icon(TablerIcons.hash),
        ),
      );
    }

    // Order destination
    if (destination != null) {
      tiles.add(
        ListTile(
          title: Text(L10().destination),
          subtitle: Text(destination!.name),
          leading: Icon(TablerIcons.map_pin, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () => {destination!.goToDetailPage(context)},
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
          "${completedLines} /  ${widget.order.lineItemCount}",
          color: lineColor,
        ),
      ),
    );

    // Extra line items
    tiles.add(
      ListTile(
        title: Text(L10().extraLineItems),
        leading: Icon(TablerIcons.clipboard_list, color: COLOR_ACTION),
        trailing: LinkIcon(text: extraLineCount.toString()),
        onTap: () => {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => POExtraLineListWidget(
                widget.order,
                filters: {"order": widget.order.pk.toString()},
              ),
            ),
          ),
        },
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().totalPrice),
        leading: Icon(TablerIcons.currency_dollar),
        trailing: LargeText(
          renderCurrency(
            widget.order.totalPrice,
            widget.order.totalPriceCurrency,
          ),
        ),
      ),
    );

    if (widget.order.issueDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().issueDate),
          trailing: LargeText(widget.order.issueDate),
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

    // Responsible "owner"
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

    // Notes tile
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

    // Attachments
    tiles.add(
      ListTile(
        title: Text(L10().attachments),
        leading: Icon(TablerIcons.file, color: COLOR_ACTION),
        trailing: LinkIcon(
          text: attachmentCount > 0 ? attachmentCount.toString() : null,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttachmentWidget(
                InvenTreePurchaseOrderAttachment(),
                widget.order.pk,
                widget.order.reference,
                widget.order.canEdit,
              ),
            ),
          );
        },
      ),
    );

    return tiles;
  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    return [
      Tab(text: L10().details),
      Tab(text: L10().lineItems),
      Tab(text: L10().received),
    ];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      ListView(children: orderTiles(context)),
      PaginatedPOLineList({"order": widget.order.pk.toString()}),
      // ListView(children: lineTiles(context)),
      PaginatedStockItemList({"purchase_order": widget.order.pk.toString()}),
    ];
  }
}
