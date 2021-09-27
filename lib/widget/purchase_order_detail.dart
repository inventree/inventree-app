import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/api.dart';
import 'package:inventree/inventree/company.dart';
import 'package:inventree/inventree/purchase_order.dart';
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

  List<Widget> orderTiles(BuildContext context) {

    List<Widget> tiles = [];

    InvenTreeCompany? supplier = order.supplier;

    print(order.jsondata);

    tiles.add(Card(
      child: ListTile(
        title: Text(order.reference),
        subtitle: Text(order.description),
        leading: supplier == null ? null : InvenTreeAPI().getImage(supplier.thumbnail, width: 40, height: 40),
        trailing: Text("${order.lineItems}"),
      )
    ));

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