import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/sales_order.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/order/so_extra_line_list.dart";
import "package:inventree/widget/order/so_line_list.dart";
import "package:inventree/widget/order/so_shipment_list.dart";
import "package:inventree/widget/refreshable_state.dart";

import "package:inventree/l10.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/progress.dart";

/*
 * Widget for viewing a single SalesOrder instance
 */
class SalesOrderDetailWidget extends StatefulWidget {
  const SalesOrderDetailWidget(this.order, {Key? key}) : super(key: key);

  final InvenTreeSalesOrder order;

  @override
  _SalesOrderDetailState createState() => _SalesOrderDetailState();
}

class _SalesOrderDetailState extends RefreshableState<SalesOrderDetailWidget> {
  _SalesOrderDetailState();

  List<InvenTreeSOLineItem> lines = [];
  int extraLineCount = 0;

  bool showCameraShortcut = true;
  bool supportsProjectCodes = false;
  int attachmentCount = 0;

  @override
  String getAppBarTitle() {
    String title = L10().salesOrder;

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
          onPressed: () {
            editOrder(context);
          },
        ),
      );
    }

    return actions;
  }

  // Add a new shipment against this sales order
  Future<void> _addShipment(BuildContext context) async {
    var fields = InvenTreeSalesOrderShipment().formFields();

    fields["order"]?["value"] = widget.order.pk;
    fields["order"]?["hidden"] = true;

    InvenTreeSalesOrderShipment().createForm(
      context,
      L10().shipmentAdd,
      fields: fields,
      onSuccess: (result) async {
        refresh(context);
      },
    );
  }

  // Add a new line item to this sales order
  Future<void> _addLineItem(BuildContext context) async {
    var fields = InvenTreeSOLineItem().formFields();

    fields["order"]?["value"] = widget.order.pk;
    fields["order"]?["hidden"] = true;

    InvenTreeSOLineItem().createForm(
      context,
      L10().lineItemAdd,
      fields: fields,
      onSuccess: (result) async {
        refresh(context);
      },
    );
  }

  /// Upload an image for this order
  Future<void> _uploadImage(BuildContext context) async {
    InvenTreeSalesOrderAttachment()
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
        await widget.order.cancelOrder().then((dynamic) {
          refresh(context);
        });
      },
    );
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

    if (widget.order.isPending) {
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

    // Add line item
    if ((widget.order.isPending || widget.order.isInProgress) &&
        InvenTreeSOLineItem().canCreate) {
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
          child: Icon(TablerIcons.circle_plus, color: Colors.green),
          label: L10().shipmentAdd,
          onTap: () async {
            _addShipment(context);
          },
        ),
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if ((widget.order.isInProgress || widget.order.isPending) &&
        InvenTreeSOLineItem().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(Icons.barcode_reader),
          label: L10().lineItemAdd,
          onTap: () async {
            scanBarcode(
              context,
              handler: SOAddItemBarcodeHandler(salesOrder: widget.order),
            );
          },
        ),
      );

      if (api.supportsBarcodeSOAllocateEndpoint) {
        actions.add(
          SpeedDialChild(
            child: Icon(TablerIcons.transition_right),
            label: L10().allocateStock,
            onTap: () async {
              scanBarcode(
                context,
                handler: SOAllocateStockHandler(salesOrder: widget.order),
              );
            },
          ),
        );
      }
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.order.reload();
    await api.SalesOrderStatus.load();

    supportsProjectCodes =
        api.supportsProjectCodes &&
        await api.getGlobalBooleanSetting(
          "PROJECT_CODES_ENABLED",
          backup: true,
        );
    showCameraShortcut = await InvenTreeSettingsManager().getBool(
      INV_SO_SHOW_CAMERA,
      true,
    );

    InvenTreeSalesOrderAttachment().countAttachments(widget.order.pk).then((
      int value,
    ) {
      if (mounted) {
        setState(() {
          attachmentCount = value;
        });
      }
    });

    // Count number of "extra line items" against this order
    InvenTreeSOExtraLineItem()
        .count(filters: {"order": widget.order.pk.toString()})
        .then((int value) {
          if (mounted) {
            setState(() {
              extraLineCount = value;
            });
          }
        });
  }

  // Edit the current SalesOrder instance
  Future<void> editOrder(BuildContext context) async {
    var fields = widget.order.formFields();

    fields.remove("customer");

    // Contact model not supported by server
    if (!api.supportsContactModel) {
      fields.remove("contact");
    }

    // ProjectCode model not supported by server
    if (!supportsProjectCodes) {
      fields.remove("project_code");
    }

    widget.order.editForm(
      context,
      L10().salesOrderEdit,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().salesOrderUpdated, success: true);
      },
    );
  }

  // Construct header tile
  Widget headerTile(BuildContext context) {
    InvenTreeCompany? customer = widget.order.customer;

    return Card(
      child: ListTile(
        title: Text(widget.order.reference),
        subtitle: Text(widget.order.description),
        leading: customer == null ? null : api.getThumbnail(customer.thumbnail),
        trailing: LargeText(
          api.SalesOrderStatus.label(widget.order.status),
          color: api.SalesOrderStatus.color(widget.order.status),
        ),
      ),
    );
  }

  List<Widget> orderTiles(BuildContext context) {
    List<Widget> tiles = [headerTile(context)];

    InvenTreeCompany? customer = widget.order.customer;

    if (supportsProjectCodes && widget.order.hasProjectCode) {
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

    if (customer != null) {
      tiles.add(
        ListTile(
          title: Text(L10().customer),
          subtitle: Text(customer.name),
          leading: Icon(TablerIcons.user, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () {
            customer.goToDetailPage(context);
          },
        ),
      );
    }

    if (widget.order.customerReference.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().customerReference),
          trailing: LargeText(widget.order.customerReference),
          leading: Icon(TablerIcons.hash),
        ),
      );
    }

    Color lineColor = widget.order.complete ? COLOR_SUCCESS : COLOR_WARNING;

    // Line items progress
    tiles.add(
      ListTile(
        title: Text(L10().lineItems),
        subtitle: ProgressBar(
          widget.order.completedLineItemCount.toDouble(),
          maximum: widget.order.lineItemCount.toDouble(),
        ),
        leading: Icon(TablerIcons.clipboard_check),
        trailing: LargeText(
          "${widget.order.completedLineItemCount} / ${widget.order.lineItemCount}",
          color: lineColor,
        ),
      ),
    );

    // Shipment progress
    if (widget.order.shipmentCount > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().shipments),
          subtitle: ProgressBar(
            widget.order.completedShipmentCount.toDouble(),
            maximum: widget.order.shipmentCount.toDouble(),
          ),
          leading: Icon(TablerIcons.cube_send),
          trailing: LargeText(
            "${widget.order.completedShipmentCount} / ${widget.order.shipmentCount}",
            color: lineColor,
          ),
        ),
      );
    }

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
              builder: (context) => SOExtraLineListWidget(
                widget.order,
                filters: {"order": widget.order.pk.toString()},
              ),
            ),
          ),
        },
      ),
    );

    // TODO: total price

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

    if (widget.order.shipmentDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().completionDate),
          trailing: LargeText(widget.order.shipmentDate),
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
                InvenTreeSalesOrderAttachment(),
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
      Tab(text: L10().shipments),
    ];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      ListView(children: orderTiles(context)),
      PaginatedSOLineList({"order": widget.order.pk.toString()}),
      PaginatedSOShipmentList({"order": widget.order.pk.toString()}),
    ];
  }
}
