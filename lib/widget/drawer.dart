import "package:adaptive_theme/adaptive_theme.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:package_info_plus/package_info_plus.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/transfer_order.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/about.dart";
import "package:inventree/settings/settings.dart";
import "package:inventree/widget/build/build_list.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/order/transfer_order_list.dart";
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
          RadioGroup<AdaptiveThemeMode>(
            groupValue: currentThemeMode,
            onChanged: (value) {
              if (value != null) {
                AdaptiveTheme.of(context).setThemeMode(value);
                onThemeSelected();
              }
            },
            child: Column(
              children: [
                RadioListTile<AdaptiveThemeMode>(
                  value: AdaptiveThemeMode.system,
                  title: Text(L10().system),
                  secondary: Icon(TablerIcons.device_desktop),
                ),
                RadioListTile<AdaptiveThemeMode>(
                  value: AdaptiveThemeMode.light,
                  title: Text(L10().lightMode),
                  secondary: Icon(TablerIcons.sun),
                ),
                RadioListTile<AdaptiveThemeMode>(
                  value: AdaptiveThemeMode.dark,
                  title: Text(L10().darkMode),
                  secondary: Icon(TablerIcons.moon),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(L10().cancel),
        ),
      ],
    );
  }
}

class InvenTreeDrawer extends StatefulWidget {
  const InvenTreeDrawer(this.parentContext);

  final BuildContext parentContext;

  @override
  State<InvenTreeDrawer> createState() => _InvenTreeDrawerState();
}

class _InvenTreeDrawerState extends State<InvenTreeDrawer> {
  void _closeDrawer() {
    Navigator.of(widget.parentContext).pop();
  }

  bool _checkConnection() {
    return InvenTreeAPI().checkConnection();
  }

  void _home() {
    _closeDrawer();
    while (Navigator.of(widget.parentContext).canPop()) {
      Navigator.of(widget.parentContext).pop();
    }
  }

  void _parts() {
    _closeDrawer();
    if (_checkConnection()) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)),
      );
    }
  }

  void _stock() {
    _closeDrawer();
    if (_checkConnection()) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)),
      );
    }
  }

  void _salesOrders() {
    _closeDrawer();
    if (_checkConnection()) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(
          builder: (context) => SalesOrderListWidget(filters: {}),
        ),
      );
    }
  }

  void _purchaseOrders() {
    _closeDrawer();
    if (_checkConnection()) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(
          builder: (context) => PurchaseOrderListWidget(filters: {}),
        ),
      );
    }
  }

  void _buildOrders() {
    _closeDrawer();
    if (_checkConnection()) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(
          builder: (context) => BuildOrderListWidget(filters: {}),
        ),
      );
    }
  }

  void _transferOrders() {
    _closeDrawer();
    if (_checkConnection()) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(
          builder: (context) => TransferOrderListWidget(filters: {}),
        ),
      );
    }
  }

  void _notifications() {
    _closeDrawer();
    if (_checkConnection()) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(builder: (context) => NotificationWidget()),
      );
    }
  }

  void _settings() {
    _closeDrawer();
    Navigator.push(
      widget.parentContext,
      MaterialPageRoute(builder: (context) => InvenTreeSettingsWidget()),
    );
  }

  void _about() {
    _closeDrawer();
    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)),
      );
    });
  }

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

  Widget? _buildUserTile() {
    if (!InvenTreeAPI().isConnected()) return null;

    final String username = InvenTreeAPI().username;
    final String email = InvenTreeAPI().userEmail;

    return ListTile(
      leading: Icon(TablerIcons.user_circle, color: COLOR_ACTION),
      title: Text(username),
      subtitle: email.isNotEmpty ? Text(email) : null,
      onTap: _about,
    );
  }

  List<Widget> drawerTiles(BuildContext context) {
    List<Widget> tiles = [];

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

    if (InvenTreeBuildOrder().canView) {
      tiles.add(
        ListTile(
          title: Text(L10().buildOrders),
          leading: Icon(TablerIcons.building_factory, color: COLOR_ACTION),
          onTap: _buildOrders,
        ),
      );
    }

    if (InvenTreeAPI().supportsTransferOrders &&
        InvenTreeTransferOrder().canView) {
      tiles.add(
        ListTile(
          title: Text(L10().transferOrders),
          leading: Icon(TablerIcons.transfer, color: COLOR_ACTION),
          onTap: _transferOrders,
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

    final int notificationCount = InvenTreeAPI().notification_counter;

    tiles.add(
      ListTile(
        leading: Icon(TablerIcons.bell, color: COLOR_ACTION),
        trailing: notificationCount > 0
            ? Text(notificationCount.toString())
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

    final Widget? userTile = _buildUserTile();
    if (userTile != null) {
      tiles.add(Divider());
      tiles.add(userTile);
    }

    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(child: ListView(children: drawerTiles(context)));
  }
}
