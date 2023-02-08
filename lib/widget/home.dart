import "dart:async";

import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/preferences.dart";
import "package:inventree/barcode.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/login.dart";
import "package:inventree/settings/settings.dart";
import "package:inventree/user_profile.dart";

import "package:inventree/inventree/notification.dart";

import "package:inventree/widget/category_display.dart";
import "package:inventree/widget/drawer.dart";
import "package:inventree/widget/location_display.dart";
import "package:inventree/widget/notifications.dart";
import "package:inventree/widget/part_list.dart";
import "package:inventree/widget/purchase_order_list.dart";
import "package:inventree/widget/search.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/spinner.dart";
import "package:inventree/widget/company_list.dart";


class InvenTreeHomePage extends StatefulWidget {

  const InvenTreeHomePage({Key? key}) : super(key: key);

  @override
  _InvenTreeHomePageState createState() => _InvenTreeHomePageState();
}

class _InvenTreeHomePageState extends State<InvenTreeHomePage> {

  _InvenTreeHomePageState() : super() {
    // Load display settings
    _loadSettings();

    // Initially load the profile and attempt server connection
    _loadProfile();

    _refreshNotifications();

    // Refresh notifications every ~30 seconds
    Timer.periodic(
        Duration(
          milliseconds: 30000,
        ), (timer) {
      _refreshNotifications();
    });

    InvenTreeAPI().registerCallback(() {

      if (mounted) {
        setState(() {
          // Reload the widget
        });
      }
    });
  }

  // Index of bottom navigation bar
  int _tabIndex = 0;

  // Number of outstanding notifications
  int _notificationCounter = 0;

  bool homeShowPo = false;
  bool homeShowSubscribed = false;
  bool homeShowManufacturers = false;
  bool homeShowCustomers = false;
  bool homeShowSuppliers = false;

  final GlobalKey<_InvenTreeHomePageState> _homeKey = GlobalKey<_InvenTreeHomePageState>();

  // Selected user profile
  UserProfile? _profile;

  void _scan(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    scanQrCode(context);
  }

  void _showParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  void _showSettings(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeSettingsWidget()));
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

  void _showSuppliers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().suppliers, {"is_supplier": "true"})));
  }

  /*
  void _showManufacturers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  void _showCustomers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().customers, {"is_customer": "true"})));
  }
   */

  void _selectProfile() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget())
    ).then((context) {
      // Once we return
      _loadProfile();
    });
  }

  Future <void> _loadSettings() async {

    homeShowSubscribed = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SUBSCRIBED, true) as bool;
    homeShowPo = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_PO, true) as bool;
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
        InvenTreeAPI().connectToServer().then((result) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }

    setState(() {});
  }

  /*
   * Refresh the number of active notifications for this user
   */
  Future<void> _refreshNotifications() async {

    if (!InvenTreeAPI().isConnected()) {
      return;
    }

    // Ignore if the widget is no longer active
    if (!mounted) {
      return;
    }

    final notifications = await InvenTreeNotification().list();

    setState(() {
      _notificationCounter = notifications.length;
    });
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
          leading: FaIcon(icon, color: connected && allowed ? COLOR_CLICK : Colors.grey),
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

    List<Widget> tiles = [];

    // Barcode scanner
    tiles.add(_listTile(
      context,
      L10().scanBarcode,
      Icons.qr_code_scanner,
      callback: () {
        _scan(context);
      }
    ));

    // Parts
    tiles.add(_listTile(
      context,
      L10().parts,
      FontAwesomeIcons.shapes,
      callback: () {
        _showParts(context);
      },
    ));

    // Starred parts
    if (homeShowSubscribed) {
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
    tiles.add(_listTile(
        context,
        L10().stock,
        FontAwesomeIcons.boxesStacked,
        callback: () {
          _showStock(context);
        }
    ));

    // Purchase orders
    if (homeShowPo) {
      tiles.add(_listTile(
          context,
          L10().purchaseOrders,
          FontAwesomeIcons.cartShopping,
          callback: () {
            _showPurchaseOrders(context);
          }
      ));
    }

    // Suppliers
    if (homeShowSuppliers) {
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
     */

    // Settings
    tiles.add(_listTile(
        context,
        L10().settings,
        FontAwesomeIcons.gears,
        callback: () {
          _showSettings(context);
        }
    ));

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
    Widget trailing = FaIcon(FontAwesomeIcons.server, color: COLOR_CLICK);
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
          Image.asset(
            "assets/image/icon.png",
            color: Colors.white.withOpacity(0.2),
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
   * Return the main body widget for display.
   * This depends on the current value of _tabIndex
   */
  Widget getBody(BuildContext context) {

    if (!InvenTreeAPI().isConnected()) {
      return _connectionStatusWidget(context);
    }

    switch (_tabIndex) {
      case 1: // Search widget
        return SearchWidget(false);
      case 2: // Notification widget
        return NotificationWidget();
      case 0: // Home widget
      default:
        return ListView(
          scrollDirection: Axis.vertical,
          children: getListTiles(context),
      );
    }
  }

  /*
   * Construct the bottom navigation bar
   */
  List<BottomNavigationBarItem> getNavBarItems(BuildContext context) {

    List<BottomNavigationBarItem> items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: FaIcon(FontAwesomeIcons.house),
        label: L10().home,
      ),
      BottomNavigationBarItem(
        icon: FaIcon(FontAwesomeIcons.magnifyingGlass),
        label: L10().search,
      ),
    ];

    if (InvenTreeAPI().supportsNotifications) {
      items.add(
          BottomNavigationBarItem(
            icon: _notificationCounter == 0 ? FaIcon(FontAwesomeIcons.bell) : Stack(
              children: <Widget>[
                FaIcon(FontAwesomeIcons.bell),
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      "${_notificationCounter}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              ],
            ),
            label: L10().notifications,
          )
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {

    var connected = InvenTreeAPI().isConnected();
    var connecting = !connected && InvenTreeAPI().isConnecting();

    return Scaffold(
      key: _homeKey,
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
      bottomNavigationBar: connected ? BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (int index) {
          setState(() {
            _tabIndex = index;
          });

          _refreshNotifications();
        },
        items: getNavBarItems(context),
      ) : null,
    );
  }
}
