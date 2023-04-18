import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/widget/dialogs.dart";
import "package:one_context/one_context.dart";

import "package:inventree/api.dart";
import "package:inventree/api_form.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/company_detail.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock_list.dart";


class PurchaseOrderDetailWidget extends StatefulWidget {

  const PurchaseOrderDetailWidget(this.order, {Key? key}): super(key: key);

  final InvenTreePurchaseOrder order;

  @override
  _PurchaseOrderDetailState createState() => _PurchaseOrderDetailState(order);
}


class _PurchaseOrderDetailState extends RefreshableState<PurchaseOrderDetailWidget> {

  _PurchaseOrderDetailState(this.order);

  final InvenTreePurchaseOrder order;

  List<InvenTreePOLineItem> lines = [];

  int completedLines = 0;

  int attachmentCount = 0;

  @override
  String getAppBarTitle() => L10().purchaseOrder;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission("purchase_order", "change")) {
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

    if (api.checkPermission("purchase_order", "add")) {
      if (order.isPending) {
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

      if (order.isOpen) {
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

  /// Issue this order
  Future<void> _issueOrder(BuildContext context) async {

    confirmationDialog(
      L10().issueOrder, "",
      icon: FontAwesomeIcons.paperPlane,
      color: Colors.blue,
      acceptText: L10().issue,
      onAccept: () async {
        await order.issueOrder().then((dynamic) {
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
        await order.cancelOrder().then((dynamic) {
          print("callback");
          refresh(context);
        });
      }
    );
  }

  @override
  Future<void> request(BuildContext context) async {
    await order.reload();

    await api.PurchaseOrderStatus.load();

    lines = await order.getLineItems();

    completedLines = 0;

    for (var line in lines) {
      if (line.isComplete) {
        completedLines += 1;
      }
    }

    attachmentCount = await InvenTreePurchaseOrderAttachment().count(
      filters: {
        "order": order.pk.toString()
      }
    );
  }

  // Edit the currently displayed PurchaseOrder
  Future <void> editOrder(BuildContext context) async {
    var fields = order.formFields();
    fields.remove("supplier");

    if (!api.supportsContactModel) {
      fields.remove("contact");
    }

    order.editForm(
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

    InvenTreeCompany? supplier = order.supplier;

    return Card(
        child: ListTile(
          title: Text(order.reference),
          subtitle: Text(order.description),
          leading: supplier == null ? null : InvenTreeAPI().getImage(supplier.thumbnail, width: 40, height: 40),
          trailing: Text(
            api.PurchaseOrderStatus.label(order.status),
            style: TextStyle(
              color: api.PurchaseOrderStatus.color(order.status)
            ),
          )
        )
    );

  }

  List<Widget> orderTiles(BuildContext context) {

    List<Widget> tiles = [];

    InvenTreeCompany? supplier = order.supplier;

    tiles.add(headerTile(context));

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

    if (order.supplierReference.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().supplierReference),
        subtitle: Text(order.supplierReference),
        leading: FaIcon(FontAwesomeIcons.hashtag),
      ));
    }

    tiles.add(ListTile(
      title: Text(L10().lineItems),
      leading: FaIcon(FontAwesomeIcons.clipboardCheck),
      trailing: Text("${completedLines} /  ${order.lineItemCount}"),
    ));

    tiles.add(ListTile(
      title: Text(L10().totalPrice),
      leading: FaIcon(FontAwesomeIcons.dollarSign),
      trailing: Text(
        renderCurrency(widget.order.totalPrice, widget.order.totalPriceCurrency)
      ),
    ));

    if (order.issueDate.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().issueDate),
        subtitle: Text(order.issueDate),
        leading: FaIcon(FontAwesomeIcons.calendarDays),
      ));
    }

    if (order.targetDate.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().targetDate),
        subtitle: Text(order.targetDate),
        leading: FaIcon(FontAwesomeIcons.calendarDays),
      ));
    }

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
                        order.pk,
                        InvenTreeAPI().checkPermission("purchase_order", "change"))
                )
            );
          },
        )
    );

    return tiles;

  }

  /*
   * Receive a specified PurchaseOrderLineItem into stock
   */
  void receiveLine(BuildContext context, InvenTreePOLineItem lineItem) {

    Map<String, dynamic> fields = {
      "line_item": {
        "parent": "items",
        "nested": true,
        "hidden": true,
        "value": lineItem.pk,
      },
      "quantity": {
        "parent": "items",
        "nested": true,
        "value": lineItem.outstanding,
      },
      "status": {
        "parent": "items",
        "nested": true,
      },
      "location": {
      },
      "barcode": {
        "parent": "items",
        "nested": true,
        "type": "barcode",
        "label": L10().barcodeAssign,
        "required": false,
      }
    };

    // TODO: Pre-fill the "location" value if the part has a default location specified

    launchApiForm(
        context,
        L10().receiveItem,
        order.receive_url,
        fields,
        method: "POST",
        icon: FontAwesomeIcons.rightToBracket,
        onSuccess: (data) async {
          showSnackIcon(L10().receivedItem, success: true);
          refresh(context);
        }
    );
  }

  /*
   * Display a context menu for a particular PurhaseOrderLineItem
   */
  void lineItemMenu(BuildContext context, InvenTreePOLineItem lineItem) {

    List<Widget> children = [];

    // TODO: Add in this option once the SupplierPart detail view is implemented
    /*
    children.add(
      SimpleDialogOption(
        onPressed: () {
          OneContext().popDialog();

          // TODO: Navigate to the "SupplierPart" display?
        },
        child: ListTile(
          title: Text(L10().viewSupplierPart),
          leading: FaIcon(FontAwesomeIcons.eye),
        )
      )
    );
     */

    if (order.isPlaced && InvenTreeAPI().supportsPoReceive) {
      children.add(
        SimpleDialogOption(
          onPressed: () {
            // Hide the dialog option
            OneContext().popDialog();

            receiveLine(context, lineItem);
          },
          child: ListTile(
            title: Text(L10().receiveItem),
            leading: FaIcon(FontAwesomeIcons.rightToBracket),
          )
        )
      );
    }

    // No valid actions available
    if (children.isEmpty) {
      return;
    }

    children.insert(0, Divider());

    OneContext().showDialog(
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(L10().lineItem),
          children: children,
        );
      }
    );

  }

  List<Widget> lineTiles(BuildContext context) {

    List<Widget> tiles = [];

    for (var line in lines) {

      InvenTreeSupplierPart? supplierPart = line.supplierPart;

      if (supplierPart != null) {

        String q = simpleNumberString(line.quantity);

        Color c = Colors.black;

        if (order.isOpen) {

          q = simpleNumberString(line.received) + " / " + simpleNumberString(line.quantity);

          if (line.isComplete) {
            c = COLOR_SUCCESS;
          } else {
            c = COLOR_DANGER;
          }
        }

        tiles.add(
          ListTile(
            title: Text(supplierPart.SKU),
            subtitle: Text(supplierPart.partName),
            leading: InvenTreeAPI().getImage(supplierPart.partImage, width: 40, height: 40),
            trailing: Text(
              q,
              style: TextStyle(
                color: c,
              ),
            ),
            onTap: () {
              lineItemMenu(context, line);
            },
          )
        );
      }
    }

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
      ListView(children: lineTiles(context)),
      PaginatedStockItemList({"purchase_order": order.pk.toString()}, true),
    ];
  }

}