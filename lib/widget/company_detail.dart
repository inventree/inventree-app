
import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/purchase_order_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";


class CompanyDetailWidget extends StatefulWidget {

  const CompanyDetailWidget(this.company, {Key? key}) : super(key: key);

  final InvenTreeCompany company;

  @override
  _CompanyDetailState createState() => _CompanyDetailState(company);

}


class _CompanyDetailState extends RefreshableState<CompanyDetailWidget> {

  _CompanyDetailState(this.company);

  final InvenTreeCompany company;

  List<InvenTreePurchaseOrder> outstandingOrders = [];

  @override
  String getAppBarTitle(BuildContext context) => L10().company;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    actions.add(
      IconButton(
        icon: FaIcon(FontAwesomeIcons.globe),
        onPressed: () async {
          company.goToInvenTreePage();
        },
      )
    );

    actions.add(
      IconButton(
        icon: FaIcon(FontAwesomeIcons.edit),
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
    await company.reload();

    if (company.isSupplier) {
      outstandingOrders = await company.getPurchaseOrders(outstanding: true);
    }
  }

  Future <void> editCompany(BuildContext context) async {

    company.editForm(
      context,
      L10().companyEdit,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().companyUpdated, success: true);
      }
    );
  }

  List<Widget> _companyTiles() {

    List<Widget> tiles = [];

    bool sep = false;

    tiles.add(Card(
      child: ListTile(
        title: Text("${company.name}"),
        subtitle: Text("${company.description}"),
        leading: InvenTreeAPI().getImage(company.image, width: 40, height: 40),
      ),
    ));

  if (company.website.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${company.website}"),
      leading: FaIcon(FontAwesomeIcons.globe),
      onTap: () {
        // TODO - Open website
      },
    ));

    sep = true;
  }

  if (company.email.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${company.email}"),
      leading: FaIcon(FontAwesomeIcons.at),
      onTap: () {
        // TODO - Open email
      },
    ));

    sep = true;
  }

  if (company.phone.isNotEmpty) {
    tiles.add(ListTile(
      title: Text("${company.phone}"),
      leading: FaIcon(FontAwesomeIcons.phone),
      onTap: () {
        // TODO - Call phone number
      },
    ));

    sep = true;
  }

    // External link
    if (company.link.isNotEmpty) {
      tiles.add(ListTile(
        title: Text("${company.link}"),
        leading: FaIcon(FontAwesomeIcons.link, color: COLOR_CLICK),
        onTap: () {
          company.openLink();
        },
      ));

      sep = true;
    }

    if (sep) {
      tiles.add(Divider());
    }

    if (company.isSupplier) {
      // TODO - Add list of supplier parts
      // TODO - Add list of purchase orders

      tiles.add(Divider());

      tiles.add(
        ListTile(
          title: Text(L10().purchaseOrders),
          leading: FaIcon(FontAwesomeIcons.shoppingCart, color: COLOR_CLICK),
          trailing: Text("${outstandingOrders.length}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseOrderListWidget(
                  filters: {
                    "supplier": "${company.pk}"
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

    if (company.isManufacturer) {
      // TODO - Add list of manufacturer parts
    }

    if (company.isCustomer) {

      // TODO - Add list of sales orders

      tiles.add(Divider());
    }

    if (company.notes.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().notes),
        leading: FaIcon(FontAwesomeIcons.stickyNote),
        onTap: null,
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