import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/inventree/attachment.dart";
import "package:inventree/inventree/parameter.dart";

import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/order/purchase_order_list.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/parameter_widget.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/company/supplier_part_list.dart";

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

  int parameterCount = 0;
  int attachmentCount = 0;

  @override
  String getAppBarTitle() {
    String title = L10().company;

    if (widget.company.name.isNotEmpty) {
      title += " -  ${widget.company.name}";
    }

    return title;
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreeCompany().canEdit) {
      actions.add(
        IconButton(
          icon: Icon(TablerIcons.edit),
          tooltip: L10().companyEdit,
          onPressed: () {
            editCompany(context);
          },
        ),
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.company.isCustomer && InvenTreeSalesOrder().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.truck),
          label: L10().salesOrderCreate,
          onTap: () async {
            _createSalesOrder(context);
          },
        ),
      );
    }

    if (widget.company.isSupplier && InvenTreePurchaseOrder().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.shopping_cart),
          label: L10().purchaseOrderCreate,
          onTap: () async {
            _createPurchaseOrder(context);
          },
        ),
      );
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
          order.goToDetailPage(context);
        }
      },
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
          order.goToDetailPage(context);
        }
      },
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

    outstandingPurchaseOrders = widget.company.isSupplier
        ? await InvenTreePurchaseOrder().count(
            filters: {
              "supplier": widget.company.pk.toString(),
              "outstanding": "true",
            },
          )
        : 0;

    outstandingSalesOrders = widget.company.isCustomer
        ? await InvenTreeSalesOrder().count(
            filters: {
              "customer": widget.company.pk.toString(),
              "outstanding": "true",
            },
          )
        : 0;

    InvenTreeSupplierPart()
        .count(filters: {"supplier": widget.company.pk.toString()})
        .then((value) {
          if (mounted) {
            setState(() {
              supplierPartCount = value;
            });
          }
        });

    InvenTreeParameter().countParameters(
      InvenTreeCompany.MODEL_TYPE,
      widget.company.pk,
    ).then((value) {
      if (mounted) {
        setState(() {
          parameterCount = value;
        });
      }
    });

    InvenTreeAttachment()
        .countAttachments(InvenTreeCompany.MODEL_TYPE, widget.company.pk)
        .then((value) {
          if (mounted) {
            setState(() {
              attachmentCount = value;
            });
          }
        });
  }

  Future<void> editCompany(BuildContext context) async {
    widget.company.editForm(
      context,
      L10().companyEdit,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().companyUpdated, success: true);
      },
    );
  }

  /*
   * Construct a list of tiles to display for this Company instance
   */
  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    bool sep = false;

    tiles.add(
      Card(
        child: ListTile(
          title: Text("${widget.company.name}"),
          subtitle: Text("${widget.company.description}"),
          leading: InvenTreeAPI().getThumbnail(widget.company.image),
        ),
      ),
    );

    if (!widget.company.active) {
      tiles.add(
        ListTile(
          title: Text(L10().inactive, style: TextStyle(color: COLOR_DANGER)),
          subtitle: Text(
            L10().inactiveCompany,
            style: TextStyle(color: COLOR_DANGER),
          ),
          leading: Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER),
        ),
      );
    }

    if (widget.company.website.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().website),
          subtitle: Text("${widget.company.website}"),
          leading: Icon(TablerIcons.globe, color: COLOR_ACTION),
          trailing: LinkIcon(external: true),
          onTap: () async {
            openLink(widget.company.website);
          },
        ),
      );

      sep = true;
    }

    if (widget.company.email.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().email),
          subtitle: Text("${widget.company.email}"),
          leading: Icon(TablerIcons.at, color: COLOR_ACTION),
          trailing: LinkIcon(external: true),
          onTap: () async {
            openLink("mailto:${widget.company.email}");
          },
        ),
      );

      sep = true;
    }

    if (widget.company.phone.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().phone),
          subtitle: Text("${widget.company.phone}"),
          leading: Icon(TablerIcons.phone, color: COLOR_ACTION),
          trailing: LinkIcon(external: true),
          onTap: () {
            openLink("tel:${widget.company.phone}");
          },
        ),
      );

      sep = true;
    }

    // External link
    if (widget.company.hasLink) {
      tiles.add(
        ListTile(
          title: Text(L10().link),
          subtitle: Text("${widget.company.link}"),
          leading: Icon(TablerIcons.link, color: COLOR_ACTION),
          trailing: LinkIcon(external: true),
          onTap: () {
            widget.company.openLink();
          },
        ),
      );

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
            leading: Icon(TablerIcons.building, color: COLOR_ACTION),
            trailing: LinkIcon(text: supplierPartCount.toString()),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupplierPartList({
                    "supplier": widget.company.pk.toString(),
                  }),
                ),
              );
            },
          ),
        );
      }

      tiles.add(
        ListTile(
          title: Text(L10().purchaseOrders),
          leading: Icon(TablerIcons.shopping_cart, color: COLOR_ACTION),
          trailing: LinkIcon(text: "${outstandingPurchaseOrders}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseOrderListWidget(
                  filters: {"supplier": "${widget.company.pk}"},
                ),
              ),
            );
          },
        ),
      );

      // TODO: Display "supplied parts" count (click through to list of supplier parts)
      /*
      tiles.add(
        ListTile(
          title: Text(L10().suppliedParts),
          leading: Icon(TablerIcons.box),
          trailing: LargeText("${company.partSuppliedCount}"),
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
          leading: Icon(TablerIcons.truck, color: COLOR_ACTION),
          trailing: LinkIcon(text: "${outstandingSalesOrders}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SalesOrderListWidget(
                  filters: {"customer": widget.company.pk.toString()},
                ),
              ),
            );
          },
        ),
      );
    }

    if (widget.company.notes.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().notes),
          subtitle: Text(widget.company.notes),
          leading: Icon(TablerIcons.note),
          onTap: null,
        ),
      );
    }

    ListTile? parameterTile = ShowParametersItem(
      context,
      InvenTreeCompany.MODEL_TYPE,
      widget.company.pk,
      parameterCount,
      widget.company.canEdit,
    );

    if (parameterTile != null) {
      tiles.add(parameterTile);
    }

    ListTile? attachmentTile = ShowAttachmentsItem(
      context,
      InvenTreeCompany.MODEL_TYPE,
      widget.company.pk,
      widget.company.name,
      attachmentCount,
      widget.company.canEdit,
    );

    if (attachmentTile != null) {
      tiles.add(attachmentTile);
    }

    return tiles;
  }
}
