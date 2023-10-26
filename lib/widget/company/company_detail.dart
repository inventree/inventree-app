import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";

import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/order/purchase_order_list.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/company/supplier_part_list.dart";
import "package:inventree/widget/order/sales_order_detail.dart";
import "package:inventree/widget/order/purchase_order_detail.dart";


/*
 * Widget for displaying detail view of a single Company instance
 */
class CompanyDetailWidget extends StatefulWidget {

  const CompanyDetailWidget(this.company, {Key? key}) : super(key: key);

  final InvenTreeCompany company;

  @override
  _CompanyDetailState createState() => _CompanyDetailState();

}


class _CompanyDetailState extends RefreshableState<CompanyDetailWidget> {

  _CompanyDetailState();

  int supplierPartCount = 0;

  int outstandingPurchaseOrders = 0;
  int outstandingSalesOrders = 0;

  int attachmentCount = 0;

  @override
  String getAppBarTitle() => L10().company;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreeCompany().canEdit) {
      actions.add(
        IconButton(
            icon: Icon(Icons.edit_square),
            tooltip: L10().companyEdit,
            onPressed: () {
              editCompany(context);
            }
        )
      );
    }
    
    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.company.isCustomer && InvenTreeSalesOrder().canCreate) {
      actions.add(SpeedDialChild(
        child: FaIcon(FontAwesomeIcons.truck),
        label: L10().salesOrderCreate,
        onTap: () async {
          _createSalesOrder(context);
        }
      ));
    }

    if (widget.company.isSupplier && InvenTreePurchaseOrder().canCreate) {
      actions.add(SpeedDialChild(
        child: FaIcon(FontAwesomeIcons.cartShopping),
        label: L10().purchaseOrderCreate,
        onTap: () async {
          _createPurchaseOrder(context);
        }
      ));
    }

    return actions;
  }

  Future<void> _createSalesOrder(BuildContext context) async {
    var fields = InvenTreeSalesOrder().formFields();

    // Cannot set contact until company is locked in
    fields.remove("contact");

    fields["customer"]?["value"] = widget.company.pk;

    InvenTreeSalesOrder().createForm(
        context,
        L10().salesOrderCreate,
        fields: fields,
        onSuccess: (result) async {
          Map<String, dynamic> data = result as Map<String, dynamic>;

          if (data.containsKey("pk")) {
            var order = InvenTreeSalesOrder.fromJson(data);

            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SalesOrderDetailWidget(order)
                )
            );
          }
        }
    );
  }

  Future<void> _createPurchaseOrder(BuildContext context) async {
    var fields = InvenTreePurchaseOrder().formFields();

    // Cannot set contact until company is locked in
    fields.remove("contact");

    fields["supplier"]?["value"] = widget.company.pk;

    InvenTreePurchaseOrder().createForm(
        context,
        L10().purchaseOrderCreate,
        fields: fields,
        onSuccess: (result) async {
          Map<String, dynamic> data = result as Map<String, dynamic>;

          if (data.containsKey("pk")) {
            var order = InvenTreePurchaseOrder.fromJson(data);

            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PurchaseOrderDetailWidget(order)
                )
            );
          }
        }
    );
  }

  @override
  Future<void> request(BuildContext context) async {
    final bool result = await widget.company.reload();

    if (!result || widget.company.pk <= 0) {
      // Company could not be loaded for some reason
      Navigator.of(context).pop();
      return;
    }

    outstandingPurchaseOrders = widget.company.isSupplier ?
        await InvenTreePurchaseOrder().count(filters: {
          "supplier": widget.company.pk.toString(),
          "outstanding": "true"
        }) : 0;

    outstandingSalesOrders = widget.company.isCustomer ?
        await InvenTreeSalesOrder().count(filters: {
          "customer": widget.company.pk.toString(),
          "outstanding": "true"
        }) : 0;
  
    InvenTreeSupplierPart().count(
        filters: {
          "supplier": widget.company.pk.toString()
        }
    ).then((value) {
      if (mounted) {
        setState(() {
          supplierPartCount = value;
        });
      }
    });

    if (api.supportCompanyAttachments) {
      InvenTreeCompanyAttachment().count(
        filters: {
          "company": widget.company.pk.toString()
        }
      ).then((value) {
        if (mounted) {
          setState(() {
            attachmentCount = value;
          });
        }
      });
    }
  }

  Future <void> editCompany(BuildContext context) async {

    widget.company.editForm(
      context,
      L10().companyEdit,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().companyUpdated, success: true);
      }
    );
  }

  /*
   * Construct a list of tiles to display for this Company instance
   */
  @override
  List<Widget> getTiles(BuildContext context) {

    List<Widget> tiles = [];

    bool sep = false;

    tiles.add(Card(
      child: ListTile(
        title: Text("${widget.company.name}"),
        subtitle: Text("${widget.company.description}"),
        leading: InvenTreeAPI().getThumbnail(widget.company.image),
      ),
    ));

  if (widget.company.website.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${widget.company.website}"),
      leading: FaIcon(FontAwesomeIcons.globe, color: COLOR_ACTION),
      onTap: () async {
        openLink(widget.company.website);
      },
    ));

    sep = true;
  }

  if (widget.company.email.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${widget.company.email}"),
      leading: FaIcon(FontAwesomeIcons.at, color: COLOR_ACTION),
      onTap: () async {
        openLink("mailto:${widget.company.email}");
      },
    ));

    sep = true;
  }

  if (widget.company.phone.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${widget.company.phone}"),
      leading: FaIcon(FontAwesomeIcons.phone, color: COLOR_ACTION),
      onTap: () {
        openLink("tel:${widget.company.phone}");
      },
    ));

    sep = true;
  }

    // External link
    if (widget.company.link.isNotEmpty) {
      tiles.add(ListTile(
        title: Text("${widget.company.link}"),
        leading: FaIcon(FontAwesomeIcons.link, color: COLOR_ACTION),
        onTap: () {
          widget.company.openLink();
        },
      ));

      sep = true;
    }

    if (sep) {
      tiles.add(Divider());
    }

    if (widget.company.isSupplier) {

      if (supplierPartCount > 0) {
        tiles.add(
          ListTile(
            title: Text(L10().supplierParts),
            leading: FaIcon(FontAwesomeIcons.building, color: COLOR_ACTION),
            trailing: Text(supplierPartCount.toString()),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupplierPartList({
                    "supplier": widget.company.pk.toString()
                  })
                )
              );
            }
          )
        );
      }

      tiles.add(
        ListTile(
          title: Text(L10().purchaseOrders),
          leading: FaIcon(FontAwesomeIcons.cartShopping, color: COLOR_ACTION),
          trailing: Text("${outstandingPurchaseOrders}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseOrderListWidget(
                  filters: {
                    "supplier": "${widget.company.pk}"
                  }
                )
              )
            );
          }
        )
      );

      // TODO: Display "supplied parts" count (click through to list of supplier parts)
      /*
      tiles.add(
        ListTile(
          title: Text(L10().suppliedParts),
          leading: FaIcon(FontAwesomeIcons.shapes),
          trailing: Text("${company.partSuppliedCount}"),
        )
      );
       */
    }

    if (widget.company.isManufacturer) {
      // TODO - Add list of manufacturer parts
    }

    if (widget.company.isCustomer) {
      tiles.add(
        ListTile(
          title: Text(L10().salesOrders),
          leading: FaIcon(FontAwesomeIcons.truck, color: COLOR_ACTION),
          trailing: Text("${outstandingSalesOrders}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SalesOrderListWidget(
                  filters: {
                    "customer": widget.company.pk.toString()
                  }
                )
              )
            );
          }
        )
      );
    }

    if (widget.company.notes.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().notes),
        leading: FaIcon(FontAwesomeIcons.noteSticky),
        onTap: null,
      ));
    }

    if (api.supportCompanyAttachments) {
      tiles.add(ListTile(
        title: Text(L10().attachments),
        leading: FaIcon(FontAwesomeIcons.fileLines, color: COLOR_ACTION),
        trailing: attachmentCount > 0 ? Text(attachmentCount.toString()) : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttachmentWidget(
                InvenTreeCompanyAttachment(),
                widget.company.pk,
                InvenTreeCompany().canEdit
              )
            )
          );
        }
      ));
    }

    return tiles;
  }

}