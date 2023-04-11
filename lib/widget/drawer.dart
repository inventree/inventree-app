import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/settings.dart";
import "package:inventree/widget/category_display.dart";
import "package:inventree/widget/notifications.dart";
import "package:inventree/widget/purchase_order_list.dart";
import "package:inventree/widget/location_display.dart";


/*
 * Custom "drawer" widget for the InvenTree app.
 */
class InvenTreeDrawer extends StatelessWidget {

  const InvenTreeDrawer(this.context);

  final BuildContext context;

  void _closeDrawer() {
    // Close the drawer
    Navigator.of(context).pop();
  }

  /*
   * Return to the 'home' screen.
   * This will empty the navigation stack.
   */
  void _home() {
    _closeDrawer();

    while (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // Load "parts" page
  void _parts() {
    _closeDrawer();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null))
    );
  }

  // Load "stock" page
  void _stock() {
    _closeDrawer();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationDisplayWidget(null))
    );
  }
  
  // Load "purchase orders" page
  void _purchaseOrders() {
    _closeDrawer();

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PurchaseOrderListWidget(filters: {})
        )
    );
  }

  // Load notifications screen
  void _notifications() {
    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationWidget()));
  }

  // Load settings widget
  void _settings() {
    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeSettingsWidget()));
  }

  // Construct list of tiles to display in the "drawer" menu
  List<Widget> drawerTiles(BuildContext context) {
    List<Widget> tiles = [];

    // "Home" access
    tiles.add(ListTile(
      leading: FaIcon(FontAwesomeIcons.house),
      title: Text(
        L10().appTitle,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: _home,
    ));

    tiles.add(Divider());

    if (InvenTreeAPI().checkPermission("part_category", "view")) {
      tiles.add(
        ListTile(
          title: Text(L10().parts),
          leading: FaIcon(FontAwesomeIcons.shapes),
          onTap: _parts,
        )
      );
    }

    if (InvenTreeAPI().checkPermission("stock_location", "view")) {
      tiles.add(
        ListTile(
          title: Text(L10().stock),
          leading: FaIcon(FontAwesomeIcons.boxesStacked),
          onTap: _stock,
        )
      );
    }

    if (InvenTreeAPI().checkPermission("purchase_order", "view")) {
      tiles.add(
        ListTile(
          title: Text(L10().purchaseOrders),
          leading: FaIcon(FontAwesomeIcons.cartShopping),
          onTap: _purchaseOrders,
        )
      );
    }

    if (tiles.length > 2) {
      tiles.add(Divider());
    }

    if (InvenTreeAPI().supportsNotifications) {
      int notification_count = InvenTreeAPI().notification_counter;

      tiles.add(
        ListTile(
          leading: FaIcon(FontAwesomeIcons.bell),
          trailing: notification_count > 0 ? Text(notification_count.toString()) : null,
          title: Text(L10().notifications),
          onTap: _notifications,
        )
      );
    }

    tiles.add(
      ListTile(
        title: Text(L10().settings),
        leading: Icon(Icons.settings),
        onTap: _settings,
      )
    );

    return tiles;
  }

  @override
  Widget build(BuildContext context) {

    return  Drawer(
        child: ListView(
          children: drawerTiles(context),
        )
    );
  }
}
