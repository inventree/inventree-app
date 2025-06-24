import "package:adaptive_theme/adaptive_theme.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/settings.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/notifications.dart";
import "package:inventree/widget/order/purchase_order_list.dart";
import "package:inventree/widget/stock/location_display.dart";

/*
 * Custom "drawer" widget for the InvenTree app.
 */
// Dialog for theme selection
class ThemeSelectionDialog extends StatelessWidget {
  const ThemeSelectionDialog({Key? key, required this.onThemeSelected})
    : super(key: key);

  final VoidCallback onThemeSelected;

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = AdaptiveTheme.of(context).mode;

    return AlertDialog(
      title: Text(L10().colorScheme),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<AdaptiveThemeMode>(
            title: Row(
              children: [
                Icon(TablerIcons.device_desktop),
                SizedBox(width: 10),
                Text("System"),
              ],
            ),
            value: AdaptiveThemeMode.system,
            groupValue: currentThemeMode,
            onChanged: (value) {
              AdaptiveTheme.of(context).setThemeMode(AdaptiveThemeMode.system);
              onThemeSelected();
            },
          ),
          RadioListTile<AdaptiveThemeMode>(
            title: Row(
              children: [
                Icon(TablerIcons.sun),
                SizedBox(width: 10),
                Text("Light"),
              ],
            ),
            value: AdaptiveThemeMode.light,
            groupValue: currentThemeMode,
            onChanged: (value) {
              AdaptiveTheme.of(context).setThemeMode(AdaptiveThemeMode.light);
              onThemeSelected();
            },
          ),
          RadioListTile<AdaptiveThemeMode>(
            title: Row(
              children: [
                Icon(TablerIcons.moon),
                SizedBox(width: 10),
                Text("Dark"),
              ],
            ),
            value: AdaptiveThemeMode.dark,
            groupValue: currentThemeMode,
            onChanged: (value) {
              AdaptiveTheme.of(context).setThemeMode(AdaptiveThemeMode.dark);
              onThemeSelected();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text("Cancel"),
        ),
      ],
    );
  }
}

class InvenTreeDrawer extends StatelessWidget {
  const InvenTreeDrawer(this.context);

  final BuildContext context;

  void _closeDrawer() {
    // Close the drawer
    Navigator.of(context).pop();
  }

  bool _checkConnection() {
    return InvenTreeAPI().checkConnection();
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

    if (_checkConnection()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)),
      );
    }
  }

  // Load "stock" page
  void _stock() {
    _closeDrawer();

    if (_checkConnection()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)),
      );
    }
  }

  // Load "sales orders" page
  void _salesOrders() {
    _closeDrawer();

    if (_checkConnection()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalesOrderListWidget(filters: {}),
        ),
      );
    }
  }

  // Load "purchase orders" page
  void _purchaseOrders() {
    _closeDrawer();

    if (_checkConnection()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseOrderListWidget(filters: {}),
        ),
      );
    }
  }

  // Load notifications screen
  void _notifications() {
    _closeDrawer();

    if (_checkConnection()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationWidget()),
      );
    }
  }

  // Load settings widget
  void _settings() {
    _closeDrawer();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InvenTreeSettingsWidget()),
    );
  }

  // Return an icon representing the current theme mode
  Widget _getThemeModeIcon(AdaptiveThemeMode mode) {
    switch (mode) {
      case AdaptiveThemeMode.dark:
        return Icon(TablerIcons.moon);
      case AdaptiveThemeMode.light:
        return Icon(TablerIcons.sun);
      case AdaptiveThemeMode.system:
        return Icon(TablerIcons.device_desktop);
    }
  }

  // Construct list of tiles to display in the "drawer" menu
  List<Widget> drawerTiles(BuildContext context) {
    List<Widget> tiles = [];

    // "Home" access
    tiles.add(
      ListTile(
        leading: Image.asset("assets/image/logo_transparent.png", height: 24),
        title: Text(
          L10().appTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: _home,
      ),
    );

    tiles.add(Divider());

    if (InvenTreePart().canView) {
      tiles.add(
        ListTile(
          title: Text(L10().parts),
          leading: Icon(TablerIcons.box, color: COLOR_ACTION),
          onTap: _parts,
        ),
      );
    }

    if (InvenTreeStockLocation().canView) {
      tiles.add(
        ListTile(
          title: Text(L10().stock),
          leading: Icon(TablerIcons.package, color: COLOR_ACTION),
          onTap: _stock,
        ),
      );
    }

    if (InvenTreePurchaseOrder().canView) {
      tiles.add(
        ListTile(
          title: Text(L10().purchaseOrders),
          leading: Icon(TablerIcons.shopping_cart, color: COLOR_ACTION),
          onTap: _purchaseOrders,
        ),
      );
    }

    if (InvenTreeSalesOrder().canView) {
      tiles.add(
        ListTile(
          title: Text(L10().salesOrders),
          leading: Icon(TablerIcons.truck_delivery, color: COLOR_ACTION),
          onTap: _salesOrders,
        ),
      );
    }

    if (tiles.length > 2) {
      tiles.add(Divider());
    }

    int notification_count = InvenTreeAPI().notification_counter;

    tiles.add(
      ListTile(
        leading: Icon(TablerIcons.bell, color: COLOR_ACTION),
        trailing: notification_count > 0
            ? Text(notification_count.toString())
            : null,
        title: Text(L10().notifications),
        onTap: _notifications,
      ),
    );

    tiles.add(Divider());

    tiles.add(
      ListTile(
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return ThemeSelectionDialog(
                onThemeSelected: () {
                  Navigator.of(dialogContext).pop();
                  _closeDrawer();
                },
              );
            },
          );
        },
        title: Text(L10().colorScheme),
        subtitle: Text(L10().colorSchemeDetail),
        leading: Icon(TablerIcons.palette, color: COLOR_ACTION),
        trailing: _getThemeModeIcon(AdaptiveTheme.of(context).mode),
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().settings),
        leading: Icon(Icons.settings, color: COLOR_ACTION),
        onTap: _settings,
      ),
    );

    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(child: ListView(children: drawerTiles(context)));
  }
}
