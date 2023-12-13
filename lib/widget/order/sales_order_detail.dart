
import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/sales_order.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/order/so_line_list.dart";
import "package:inventree/widget/order/so_shipment_list.dart";
import "package:inventree/widget/refreshable_state.dart";

import "package:inventree/l10.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/company/company_detail.dart";
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

  bool supportsProjectCodes = false;
  int attachmentCount = 0;

  @override
  String getAppBarTitle() => L10().salesOrder;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.order.canEdit) {
      actions.add(
        IconButton(
          icon: Icon(Icons.edit_square),
          onPressed: () {
            editOrder(context);
          },
        )
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
      }
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
        }
    );
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    // Add line item
    if (widget.order.isOpen && InvenTreeSOLineItem().canCreate) {
      actions.add(
        SpeedDialChild(
          child: FaIcon(FontAwesomeIcons.circlePlus),
          label: L10().lineItemAdd,
          onTap: () async {
            _addLineItem(context);
          }
        )
      );

      actions.add(
        SpeedDialChild(
          child: FaIcon(FontAwesomeIcons.circlePlus),
          label: L10().shipmentAdd,
          onTap: () async {
            _addShipment(context);
          }
        )
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.order.isOpen && InvenTreeSOLineItem().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(Icons.barcode_reader),
          label: L10().lineItemAdd,
          onTap: () async {
            scanBarcode(
              context,
              handler: SOAddItemBarcodeHandler(salesOrder: widget.order),
            );
          }
        )
      );

      if (api.supportsBarcodeSOAllocateEndpoint) {
        actions.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.rightToBracket),
            label: L10().allocateStock,
            onTap: () async {
              scanBarcode(
                context,
                handler: SOAllocateStockHandler(
                  salesOrder: widget.order,
                )
              );
            }
          )
        );
      }
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.order.reload();
    await api.SalesOrderStatus.load();

    supportsProjectCodes = api.supportsProjectCodes && await api.getGlobalBooleanSetting("PROJECT_CODES_ENABLED");

    InvenTreeSalesOrderAttachment().count(filters: {
      "order": widget.order.pk.toString()
    }).then((int value) {
      if (mounted) {
        setState(() {
          attachmentCount = value;
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
      }
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
        trailing: Text(
          api.SalesOrderStatus.label(widget.order.status),
          style: TextStyle(
              color: api.SalesOrderStatus.color(widget.order.status)
          ),
        ),
      )
    );
  }

  List<Widget> orderTiles(BuildContext context) {

    List<Widget> tiles = [
      headerTile(context)
    ];

    InvenTreeCompany? customer = widget.order.customer;

    if (supportsProjectCodes && widget.order.hasProjectCode) {
      tiles.add(ListTile(
        title: Text(L10().projectCode),
        subtitle: Text("${widget.order.projectCode} - ${widget.order.projectCodeDescription}"),
        leading: FaIcon(FontAwesomeIcons.list),
      ));
    }

    if (customer != null) {
      tiles.add(ListTile(
        title: Text(L10().customer),
        subtitle: Text(customer.name),
        leading: FaIcon(FontAwesomeIcons.userTie, color: COLOR_ACTION),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CompanyDetailWidget(customer)
              )
          );
        }
      ));
    }

    if (widget.order.customerReference.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().customerReference),
        subtitle: Text(widget.order.customerReference),
        leading: FaIcon(FontAwesomeIcons.hashtag),
      ));
    }

    Color lineColor = widget.order.complete ? COLOR_SUCCESS : COLOR_WARNING;

    tiles.add(ListTile(
      title: Text(L10().lineItems),
      subtitle: ProgressBar(
        widget.order.completedLineItemCount.toDouble(),
        maximum: widget.order.lineItemCount.toDouble()
      ),
      leading: FaIcon(FontAwesomeIcons.clipboardCheck),
      trailing: Text("${widget.order.completedLineItemCount} / ${widget.order.lineItemCount}", style: TextStyle(color: lineColor)),
    ));

    // TODO: total price

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
            InvenTreeSalesOrderAttachment(),
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