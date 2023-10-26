
import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/refreshable_state.dart";

import "package:inventree/l10.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/notes_widget.dart";

import "package:inventree/widget/snacks.dart";

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
  int completedLines = 0;
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

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    // TODO:

    return actions;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    // TODO

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.order.reload();
    await api.SalesOrderStatus.load();

    supportsProjectCodes = api.supportsProjectCodes && await api.getGlobalBooleanSetting("PROJECT_CODES_ENABLED");

    completedLines = 0;

    for (var line in lines) {
      if (line.isComplete) {
        completedLines += 1;
      }
    }

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
        onTap: () {
          // TODO
        }
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
          // TODO
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

    Color lineColor = completedLines < widget.order.lineItemCount ? COLOR_WARNING : COLOR_SUCCESS;

    tiles.add(ListTile(
      title: Text(L10().lineItems),
      leading: FaIcon(FontAwesomeIcons.clipboardCheck),
      trailing: Text("${completedLines} / ${widget.order.lineItemCount}", style: TextStyle(color: lineColor)),
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
      Tab(text: L10().shipped)
    ];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      ListView(children: orderTiles(context)),
      Center(), // TODO: Line items
      Center(), // TODO: Delivered stock
    ];
  }

}