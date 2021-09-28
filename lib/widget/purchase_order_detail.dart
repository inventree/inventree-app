import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/api.dart';
import 'package:inventree/app_colors.dart';
import 'package:inventree/inventree/company.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/inventree/purchase_order.dart';
import 'package:inventree/widget/company_detail.dart';
import 'package:inventree/widget/refreshable_state.dart';

import '../l10.dart';
import 'location_display.dart';


class PurchaseOrderDetailWidget extends StatefulWidget {

  PurchaseOrderDetailWidget(this.order, {Key? key}): super(key: key);

  final InvenTreePurchaseOrder order;

  @override
  _PurchaseOrderDetailState createState() => _PurchaseOrderDetailState(order);
}


class _PurchaseOrderDetailState extends RefreshableState<PurchaseOrderDetailWidget> {

  _PurchaseOrderDetailState(this.order);

  final InvenTreePurchaseOrder order;

  List<InvenTreePOLineItem> lines = [];

  int completedLines = 0;

  @override
  String getAppBarTitle(BuildContext context) => L10().purchaseOrder;

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission("purchase_order", "change")) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.edit),
          tooltip: L10().edit,
          onPressed: () {
            editOrder(context);
          }
        )
      );
    }

    return actions;
  }

  @override
  Future<void> request() async {
    await order.reload();

    lines = await order.getLineItems();

    completedLines = 0;

    for (var line in lines) {
      if (line.isComplete) {
        completedLines += 1;
      }
    }

  }

  void editOrder(BuildContext context) async {

    order.editForm(
      context,
      L10().purchaseOrderEdit,
      onSuccess: (data) async {
        refresh();
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
        leading: FaIcon(FontAwesomeIcons.building, color: COLOR_CLICK),
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
      leading: FaIcon(FontAwesomeIcons.clipboardList, color: COLOR_CLICK),
      trailing: Text("${order.lineItemCount}"),
      onTap: () {
        setState(() {
          // Switch to the "line items" tab
          tabIndex = 1;
        });
      },
    ));

    tiles.add(ListTile(
      title: Text(L10().received),
      leading: FaIcon(FontAwesomeIcons.clipboardCheck, color: COLOR_CLICK),
      trailing: Text("${completedLines}"),
      onTap: () {
        setState(() {
          // Switch to the "received items" tab
          tabIndex = 2;
        });
      },
    ));

    if (order.issueDate.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().issueDate),
        subtitle: Text(order.issueDate),
        leading: FaIcon(FontAwesomeIcons.calendarAlt),
      ));
    }

    if (order.targetDate.isNotEmpty) {
      tiles.add(ListTile(
        title: Text(L10().targetDate),
        subtitle: Text(order.targetDate),
        leading: FaIcon(FontAwesomeIcons.calendarAlt),
      ));
    }

    return tiles;

  }

  List<Widget> lineTiles(BuildContext context) {

    List<Widget> tiles = [];

    tiles.add(headerTile(context));

    for (var line in lines) {

      InvenTreeSupplierPart? supplierPart = line.supplierPart;

      if (supplierPart == null) {
        continue;
      } else {
        tiles.add(
          ListTile(
            title: Text(supplierPart.SKU),
            subtitle: Text(supplierPart.partName),
            leading: InvenTreeAPI().getImage(supplierPart.partImage, width: 40, height: 40),
            trailing: Text("${line.quantity}"),
          )
        );
      }
    }

    return tiles;
  }

  @override
  Widget getBody(BuildContext context) {

    return Center(
      child: getSelectedWidget(context, tabIndex),
    );
  }

  Widget getSelectedWidget(BuildContext context, int index) {
    switch (index) {
      case 0:
        return ListView(
          children: orderTiles(context)
        );
      case 1:
        return ListView(
          children: lineTiles(context)
        );
      case 2:
        // Stock items received against this order
        Map<String, String> filters = {
          "purchase_order": "${order.pk}"
        };

        return PaginatedStockList(filters);

      default:
        return ListView();
    }
  }

  @override
  Widget getBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: tabIndex,
      onTap: onTabSelectionChanged,
      items: [
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.info),
          label: L10().details
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.thList),
          label: L10().lineItems,
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.boxes),
          label: L10().stockItems
        )
      ],
    );
  }

}