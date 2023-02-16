import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";

import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/purchase_order_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/supplier_part_list.dart";

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

  List<InvenTreePurchaseOrder> outstandingOrders = [];
  
  int supplierPartCount = 0;

  int attachmentCount = 0;

  @override
  String getAppBarTitle(BuildContext context) => L10().company;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    actions.add(
      IconButton(
        icon: FaIcon(FontAwesomeIcons.globe),
        onPressed: () async {
          widget.company.goToInvenTreePage();
        },
      )
    );

    actions.add(
      IconButton(
        icon: FaIcon(FontAwesomeIcons.penToSquare),
        tooltip: L10().edit,
        onPressed: () {
          editCompany(context);
        }
      )
    );

    return actions;

  }

  @override
  Future<void> request(BuildContext context) async {
    final bool result = await widget.company.reload();

    if (!result || widget.company.pk <= 0) {
      // Company could not be loaded for some reason
      Navigator.of(context).pop();
      return;
    }

    if (widget.company.isSupplier) {
      outstandingOrders =
      await widget.company.getPurchaseOrders(outstanding: true);
    }

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
  List<Widget> _companyTiles() {

    List<Widget> tiles = [];

    bool sep = false;

    tiles.add(Card(
      child: ListTile(
        title: Text("${widget.company.name}"),
        subtitle: Text("${widget.company.description}"),
        leading: InvenTreeAPI().getImage(widget.company.image, width: 40, height: 40),
      ),
    ));

  if (widget.company.website.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${widget.company.website}"),
      leading: FaIcon(FontAwesomeIcons.globe),
      onTap: () {
        // TODO - Open website
      },
    ));

    sep = true;
  }

  if (widget.company.email.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${widget.company.email}"),
      leading: FaIcon(FontAwesomeIcons.at),
      onTap: () {
        // TODO - Open email
      },
    ));

    sep = true;
  }

  if (widget.company.phone.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${widget.company.phone}"),
      leading: FaIcon(FontAwesomeIcons.phone),
      onTap: () {
        // TODO - Call phone number
      },
    ));

    sep = true;
  }

    // External link
    if (widget.company.link.isNotEmpty) {
      tiles.add(ListTile(
        title: Text("${widget.company.link}"),
        leading: FaIcon(FontAwesomeIcons.link, color: COLOR_CLICK),
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
            leading: FaIcon(FontAwesomeIcons.building, color: COLOR_CLICK),
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
          leading: FaIcon(FontAwesomeIcons.cartShopping, color: COLOR_CLICK),
          trailing: Text("${outstandingOrders.length}"),
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

      // TODO - Add list of sales orders

      tiles.add(Divider());
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
        leading: FaIcon(FontAwesomeIcons.fileLines, color: COLOR_CLICK),
        trailing: attachmentCount > 0 ? Text(attachmentCount.toString()) : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttachmentWidget(
                InvenTreeCompanyAttachment(),
                widget.company.pk,
                api.checkPermission("purchase_order", "change") || api.checkPermission("sales_order", "change")
              )
            )
          );
        }
      ));
    }

    return tiles;
  }

  @override
  Widget getBody(BuildContext context) {

    return Center(
      child: ListView(
        children: _companyTiles(),
      )
    );
  }
}