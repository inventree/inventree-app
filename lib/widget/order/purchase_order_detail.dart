import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/order/po_line_list.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/purchase_order.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/company/company_detail.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock/stock_list.dart";


/*
 * Widget for viewing a single PurchaseOrder instance
 */
class PurchaseOrderDetailWidget extends StatefulWidget {

  const PurchaseOrderDetailWidget(this.order, {Key? key}): super(key: key);

  final InvenTreePurchaseOrder order;

  @override
  _PurchaseOrderDetailState createState() => _PurchaseOrderDetailState();
}


class _PurchaseOrderDetailState extends RefreshableState<PurchaseOrderDetailWidget> {

  _PurchaseOrderDetailState();
  
  List<InvenTreePOLineItem> lines = [];

  int completedLines = 0;

  int attachmentCount = 0;

  bool supportProjectCodes = false;

  @override
  String getAppBarTitle() => L10().purchaseOrder;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.order.canEdit) {
      actions.add(
        IconButton(
          icon: Icon(Icons.edit_square),
          tooltip: L10().purchaseOrderEdit,
          onPressed: () {
            editOrder(context);
          }
        )
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.order.canCreate) {
      if (widget.order.isPending) {

        actions.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.circlePlus, color: Colors.green),
            label: L10().lineItemAdd,
            onTap: () async {
              _addLineItem(context);
            }
          )
        );

        actions.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.paperPlane, color: Colors.blue),
            label: L10().issueOrder,
            onTap: () async {
              _issueOrder(context);
            }
          )
        );
      }

      if (widget.order.isOpen) {
        actions.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.circleXmark, color: Colors.red),
            label: L10().cancelOrder,
            onTap: () async {
              _cancelOrder(context);
            }
          )
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
    fields["part"]?["filters"] = {
      "supplier": widget.order.supplierId
    };

    fields["order"]?["value"] = widget.order.pk;

    InvenTreePOLineItem().createForm(
      context,
      L10().lineItemAdd,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().lineItemUpdated, success: true);
      }
    );
  }

  /// Issue this order
  Future<void> _issueOrder(BuildContext context) async {

    confirmationDialog(
      L10().issueOrder, "",
      icon: FontAwesomeIcons.paperPlane,
      color: Colors.blue,
      acceptText: L10().issue,
      onAccept: () async {
        await widget.order.issueOrder().then((dynamic) {
          refresh(context);
        });
      }
    );
  }

  /// Cancel this order
  Future<void> _cancelOrder(BuildContext context) async {

    confirmationDialog(
      L10().cancelOrder, "",
      icon: FontAwesomeIcons.circleXmark,
      color: Colors.red,
      acceptText: L10().cancel,
      onAccept: () async {
        await widget.order.cancelOrder().then((dynamic) {
          print("callback");
          refresh(context);
        });
      }
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
          onTap:() async {
            scanBarcode(
              context,
              handler: POReceiveBarcodeHandler(purchaseOrder: widget.order),
            ).then((value) {
              refresh(context);
            });
          },
        )
      );
    }

    if (widget.order.isPending && api.supportsBarcodePOAddLineEndpoint) {
      actions.add(
        SpeedDialChild(
          child: FaIcon(FontAwesomeIcons.circlePlus, color: COLOR_SUCCESS),
          label: L10().lineItemAdd,
          onTap: () async {
            scanBarcode(
              context,
              handler: POAllocateBarcodeHandler(purchaseOrder: widget.order),
            );
          }
        )
      );
    }

    return actions;
  }


  @override
  Future<void> request(BuildContext context) async {
    await widget.order.reload();

    await api.PurchaseOrderStatus.load();

    lines = await widget.order.getLineItems();

    supportProjectCodes = api.supportsProjectCodes && await api.getGlobalBooleanSetting("PROJECT_CODES_ENABLED");

    completedLines = 0;

    for (var line in lines) {
      if (line.isComplete) {
        completedLines += 1;
      }
    }

    InvenTreePurchaseOrderAttachment().count(filters: {
      "order": widget.order.pk.toString()
    }).then((int value) {
      if (mounted) {
        setState(() {
          attachmentCount = value;
        });
      }
    });
  }

  // Edit the currently displayed PurchaseOrder
  Future <void> editOrder(BuildContext context) async {
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
      }
    );
  }

  Widget headerTile(BuildContext context) {

    InvenTreeCompany? supplier = widget.order.supplier;

    return Card(
        child: ListTile(
          title: Text(widget.order.reference),
          subtitle: Text(widget.order.description),
          leading: supplier == null ? null : api.getThumbnail(supplier.thumbnail),
          trailing: Text(
            api.PurchaseOrderStatus.label(widget.order.status),
            style: TextStyle(
              color: api.PurchaseOrderStatus.color(widget.order.status)
            ),
          )
        )
    );

  }

  List<Widget> orderTiles(BuildContext context) {

    List<Widget> tiles = [];

    InvenTreeCompany? supplier = widget.order.supplier;

    tiles.add(headerTile(context));

    if (supportProjectCodes && widget.order.hasProjectCode) {
      tiles.add(ListTile(
        title: Text(L10().projectCode),
        subtitle: Text("${widget.order.projectCode} - ${widget.order.projectCodeDescription}"),
        leading: FaIcon(FontAwesomeIcons.list),
      ));
    }

    if (supplier != null) {
      tiles.add(ListTile(
        title: Text(L10().supplier),
        subtitle: Text(supplier.name),
        leading: FaIcon(FontAwesomeIcons.building, color: COLOR_ACTION),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompanyDetailWidget(supplier)
            )
          );
        },
      ));
    }

    if (widget.order.supplierReference.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().supplierReference),
        subtitle: Text(widget.order.supplierReference),
        leading: FaIcon(FontAwesomeIcons.hashtag),
      ));
    }

    Color lineColor = completedLines < widget.order.lineItemCount ? COLOR_WARNING : COLOR_SUCCESS;

    tiles.add(ListTile(
      title: Text(L10().lineItems),
      subtitle: ProgressBar(
        completedLines.toDouble(),
        maximum: widget.order.lineItemCount.toDouble(),
      ),
      leading: FaIcon(FontAwesomeIcons.clipboardCheck),
      trailing: Text("${completedLines} /  ${widget.order.lineItemCount}", style: TextStyle(color: lineColor)),
    ));

    tiles.add(ListTile(
      title: Text(L10().totalPrice),
      leading: FaIcon(FontAwesomeIcons.dollarSign),
      trailing: Text(
        renderCurrency(widget.order.totalPrice, widget.order.totalPriceCurrency)
      ),
    ));

    if (widget.order.issueDate.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().issueDate),
        subtitle: Text(widget.order.issueDate),
        leading: FaIcon(FontAwesomeIcons.calendarDays),
      ));
    }

    if (widget.order.targetDate.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().targetDate),
        subtitle: Text(widget.order.targetDate),
        leading: FaIcon(FontAwesomeIcons.calendarDays),
      ));
    }

    // Notes tile
    tiles.add(
        ListTile(
          title: Text(L10().notes),
          leading: FaIcon(FontAwesomeIcons.noteSticky, color: COLOR_ACTION),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotesWidget(widget.order)
              )
            );
          },
        )
    );

    // Attachments
    tiles.add(
        ListTile(
          title: Text(L10().attachments),
          leading: FaIcon(FontAwesomeIcons.fileLines, color: COLOR_ACTION),
          trailing: attachmentCount > 0 ? Text(attachmentCount.toString()) : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttachmentWidget(
                    InvenTreePurchaseOrderAttachment(),
                    widget.order.pk,
                    widget.order.canEdit
                )
              )
            );
          },
        )
    );

    return tiles;

  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    return [
      Tab(text: L10().details),
      Tab(text: L10().lineItems),
      Tab(text: L10().received)
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