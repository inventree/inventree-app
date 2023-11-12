import "dart:async";

import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/preferences.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/select_server.dart";
import "package:inventree/user_profile.dart";

import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/drawer.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/part/part_list.dart";
import "package:inventree/widget/order/purchase_order_list.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/spinner.dart";
import "package:inventree/widget/company/company_list.dart";


class InvenTreeHomePage extends StatefulWidget {

  const InvenTreeHomePage({Key? key}) : super(key: key);

  @override
  _InvenTreeHomePageState createState() => _InvenTreeHomePageState();
}


class _InvenTreeHomePageState extends State<InvenTreeHomePage> with BaseWidgetProperties {

  _InvenTreeHomePageState() : super() {
    // Load display settings
    _loadSettings();

    // Initially load the profile and attempt server connection
    _loadProfile();

    InvenTreeAPI().registerCallback(() {

      if (mounted) {
        setState(() {
          // Reload the widget
        });
      }
    });
  }

  final homeKey = GlobalKey<ScaffoldState>();

  bool homeShowPo = false;
  bool homeShowSo = false;
  bool homeShowSubscribed = false;
  bool homeShowManufacturers = false;
  bool homeShowCustomers = false;
  bool homeShowSuppliers = false;

  // Selected user profile
  UserProfile? _profile;

  void _showParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  void _showStarredParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartList({
          "starred": "true"
        })
      )
    );
  }

  void _showStock(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
  }

  void _showPurchaseOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseOrderListWidget(filters: {})
      )
    );
  }

  void _showSalesOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SalesOrderListWidget(filters: {})
        )
    );
  }

  void _showSuppliers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().suppliers, {"is_supplier": "true"})));
  }

  /*
  void _showManufacturers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  */
  void _showCustomers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().customers, {"is_customer": "true"})));
  }

  void _selectProfile() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => InvenTreeSelectServerWidget())
    ).then((context) {
      // Once we return
      _loadProfile();
    });
  }

  Future <void> _loadSettings() async {

    homeShowSubscribed = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SUBSCRIBED, true) as bool;
    homeShowPo = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_PO, true) as bool;
    homeShowSo = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SO, true) as bool;
    homeShowManufacturers = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_MANUFACTURERS, true) as bool;
    homeShowCustomers = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_CUSTOMERS, true) as bool;
    homeShowSuppliers = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SUPPLIERS, true) as bool;

    setState(() {
    });
  }

  Future <void> _loadProfile() async {

    _profile = await UserProfileDBManager().getSelectedProfile();

    // A valid profile was loaded!
    if (_profile != null) {
      if (!InvenTreeAPI().isConnected() && !InvenTreeAPI().isConnecting()) {

        // Attempt server connection
        InvenTreeAPI().connectToServer(_profile!).then((result) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }

    setState(() {});
  }

  Widget _listTile(BuildContext context, String label, IconData icon, {Function()? callback, String role = "", String permission = "", Widget? trailing}) {

    bool connected = InvenTreeAPI().isConnected();

    bool allowed = true;

    if (role.isNotEmpty || permission.isNotEmpty) {
      allowed = InvenTreeAPI().checkPermission(role, permission);
    }

    return GestureDetector(
      child: Card(
        margin: EdgeInsets.symmetric(
          vertical: 5,
          horizontal: 12
        ),
        child: ListTile(
          leading: FaIcon(icon, color: connected && allowed ? COLOR_ACTION : Colors.grey),
          title: Text(label),
          trailing: trailing,
        ),
      ),
      onTap: () {
        if (!allowed) {
          showSnackIcon(
            L10().permissionRequired,
            icon: FontAwesomeIcons.circleExclamation,
            success: false,
          );
          return;
        }

        if (callback != null) {
          callback();
        }
      },
    );
  }

  /*
   * Constructs a list of tiles for the main screen
   */
  List<Widget> getListTiles(BuildContext context) {

    List<Widget> tiles = [
      Divider(height: 5)
    ];

    // Parts
    if (InvenTreePart().canView) {
      tiles.add(_listTile(
        context,
        L10().parts,
        FontAwesomeIcons.shapes,
        callback: () {
          _showParts(context);
        },
      ));
    }

    // Starred parts
    if (homeShowSubscribed && InvenTreePart().canView) {
      tiles.add(_listTile(
        context,
        L10().partsStarred,
        FontAwesomeIcons.bell,
        callback: () {
          _showStarredParts(context);
        }
      ));
    }

    // Stock button
    if (InvenTreeStockItem().canView) {
      tiles.add(_listTile(
          context,
          L10().stock,
          FontAwesomeIcons.boxesStacked,
          callback: () {
            _showStock(context);
          }
      ));
    }

    // Purchase orders
    if (homeShowPo && InvenTreePurchaseOrder().canView) {
      tiles.add(_listTile(
          context,
          L10().purchaseOrders,
          FontAwesomeIcons.cartShopping,
          callback: () {
            _showPurchaseOrders(context);
          }
      ));
    }

    if (homeShowSo && InvenTreeSalesOrder().canView) {
      tiles.add(_listTile(
        context,
        L10().salesOrders,
        FontAwesomeIcons.truck,
        callback: () {
          _showSalesOrders(context);
        }
      ));
    }

    // Suppliers
    if (homeShowSuppliers && InvenTreePurchaseOrder().canView) {
      tiles.add(_listTile(
          context,
          L10().suppliers,
          FontAwesomeIcons.building,
          callback: () {
            _showSuppliers(context);
          }
      ));
    }

    // TODO: Add these tiles back in once the features are fleshed out
    /*


    // Manufacturers
    if (homeShowManufacturers) {
      tiles.add(_listTile(
          context,
          L10().manufacturers,
          FontAwesomeIcons.industry,
          callback: () {
            _showManufacturers(context);
          }
      ));
    }
    */
    // Customers
    if (homeShowCustomers) {
      tiles.add(_listTile(
          context,
          L10().customers,
          FontAwesomeIcons.userTie,
          callback: () {
            _showCustomers(context);
          }
      ));
    }

    return tiles;
  }

  /*
   * If the app is not connected to an InvenTree server,
   * display a connection status widget
   */
  Widget _connectionStatusWidget(BuildContext context) {

    String? serverAddress = InvenTreeAPI().serverAddress;
    bool validAddress = serverAddress != null;
    bool connecting = !InvenTreeAPI().isConnected() && InvenTreeAPI().isConnecting();

    Widget leading = FaIcon(FontAwesomeIcons.circleExclamation, color: COLOR_DANGER);
    Widget trailing = FaIcon(FontAwesomeIcons.server, color: COLOR_ACTION);
    String title = L10().serverNotConnected;
    String subtitle = L10().profileSelectOrCreate;

    if (!validAddress) {
      title = L10().serverNotSelected;
    } else if (connecting) {
      title = L10().serverConnecting;
      subtitle = serverAddress;
      leading = Spinner(icon: FontAwesomeIcons.spinner, color: COLOR_PROGRESS);
    }

    return Center(
      child: Column(
        children: [
          Spacer(),
          Image.asset(
            "assets/image/logo_transparent.png",
            color: Colors.white.withOpacity(0.05),
            colorBlendMode: BlendMode.modulate,
            scale: 0.5,
          ),
          Spacer(),
          ListTile(
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: trailing,
            leading: leading,
            onTap: _selectProfile,
          )
        ]
      ),
    );
  }

  /*
   * Return the main body widget for display
   */
  @override
  Widget getBody(BuildContext context) {

    if (!InvenTreeAPI().isConnected()) {
      return _connectionStatusWidget(context);
    }

    return ListView(
        scrollDirection: Axis.vertical,
        children: getListTiles(context),
    );
  }

  @override
  Widget build(BuildContext context) {

    var connected = InvenTreeAPI().isConnected();
    var connecting = !connected && InvenTreeAPI().isConnecting();

    return Scaffold(
      key: homeKey,
      appBar: AppBar(
        title: Text(L10().appTitle),
        actions: [
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.server,
              color: connected ? COLOR_SUCCESS : (connecting ? COLOR_PROGRESS: COLOR_DANGER),
            ),
            onPressed: _selectProfile,
          )
        ],
      ),
      drawer: InvenTreeDrawer(context),
      body: getBody(context),
      bottomNavigationBar: InvenTreeAPI().isConnected() ? buildBottomAppBar(context, homeKey) : null,
    );
  }
}
