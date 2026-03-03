import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

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
import "package:inventree/widget/order/so_shipment_list.dart";

import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/drawer.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/part/part_list.dart";
import "package:inventree/widget/order/purchase_order_list.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/build/build_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/spinner.dart";
import "package:inventree/widget/company/company_list.dart";

class InvenTreeHomePage extends StatefulWidget {
  const InvenTreeHomePage({Key? key}) : super(key: key);

  @override
  _InvenTreeHomePageState createState() => _InvenTreeHomePageState();
}

class _InvenTreeHomePageState extends State<InvenTreeHomePage>
    with BaseWidgetProperties {
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
  bool homeShowShipments = false;
  bool homeShowBuild = false;
  bool homeShowSubscribed = false;
  bool homeShowManufacturers = false;
  bool homeShowCustomers = false;
  bool homeShowSuppliers = false;

  // Selected user profile
  UserProfile? _profile;

  void _showParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)),
    );
  }

  void _showStarredParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PartList({"starred": "true"})),
    );
  }

  void _showStock(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)),
    );
  }

  void _showPurchaseOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseOrderListWidget(filters: {}),
      ),
    );
  }

  void _showSalesOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesOrderListWidget(filters: {}),
      ),
    );
  }

  void _showPendingShipments(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SOShipmentListWidget(
          title: L10().shipmentsPending,
          filters: {"order_outstanding": "true", "shipped": "false"},
        ),
      ),
    );
  }

  void _showBuildOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuildOrderListWidget(filters: {}),
      ),
    );
  }

  void _showSuppliers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CompanyListWidget(L10().suppliers, {"is_supplier": "true"}),
      ),
    );
  }

  /*
  void _showManufacturers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  */
  void _showCustomers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CompanyListWidget(L10().customers, {"is_customer": "true"}),
      ),
    );
  }

  void _selectProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InvenTreeSelectServerWidget()),
    ).then((context) {
      // Once we return
      _loadProfile();
    });
  }

  Future<void> _loadSettings() async {
    homeShowSubscribed =
        await InvenTreeSettingsManager().getValue(
              INV_HOME_SHOW_SUBSCRIBED,
              true,
            )
            as bool;
    homeShowPo =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_PO, true)
            as bool;
    homeShowSo =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SO, true)
            as bool;

    homeShowShipments =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SHIPMENTS, true)
            as bool;

    homeShowBuild =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_BUILD, true)
            as bool;

    homeShowManufacturers =
        await InvenTreeSettingsManager().getValue(
              INV_HOME_SHOW_MANUFACTURERS,
              true,
            )
            as bool;
    homeShowCustomers =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_CUSTOMERS, true)
            as bool;
    homeShowSuppliers =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SUPPLIERS, true)
            as bool;

    setState(() {});
  }

  Future<void> _loadProfile() async {
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

  Widget _listTile(
    BuildContext context,
    String label,
    IconData icon, {
    Function()? callback,
    String role = "",
    String permission = "",
    Widget? trailing,
  }) {
    bool connected = InvenTreeAPI().isConnected();

    bool allowed = true;

    if (role.isNotEmpty || permission.isNotEmpty) {
      allowed = InvenTreeAPI().checkRole(role, permission);
    }

    return GestureDetector(
      child: Card(
        margin: EdgeInsets.all(5),
        child: Align(
          child: ListTile(
            leading: Icon(
              icon,
              color: connected && allowed ? COLOR_ACTION : Colors.grey,
            ),
            title: Text(label),
            trailing: trailing,
          ),
          alignment: Alignment.center,
        ),
      ),
      onTap: () {
        if (!allowed) {
          showSnackIcon(
            L10().permissionRequired,
            icon: TablerIcons.exclamation_circle,
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

    // Parts
    if (InvenTreePart().canView) {
      tiles.add(
        _listTile(
          context,
          L10().parts,
          TablerIcons.box,
          callback: () {
            _showParts(context);
          },
        ),
      );
    }

    // Starred parts
    if (homeShowSubscribed && InvenTreePart().canView) {
      tiles.add(
        _listTile(
          context,
          L10().partsStarred,
          TablerIcons.bell,
          callback: () {
            _showStarredParts(context);
          },
        ),
      );
    }

    // Stock button
    if (InvenTreeStockItem().canView) {
      tiles.add(
        _listTile(
          context,
          L10().stock,
          TablerIcons.package,
          callback: () {
            _showStock(context);
          },
        ),
      );
    }

    // Purchase orders
    if (homeShowPo && InvenTreePurchaseOrder().canView) {
      tiles.add(
        _listTile(
          context,
          L10().purchaseOrders,
          TablerIcons.shopping_cart,
          callback: () {
            _showPurchaseOrders(context);
          },
        ),
      );
    }

    if (homeShowSo && InvenTreeSalesOrder().canView) {
      tiles.add(
        _listTile(
          context,
          L10().salesOrders,
          TablerIcons.truck_delivery,
          callback: () {
            _showSalesOrders(context);
          },
        ),
      );
    }

    if (homeShowShipments && InvenTreeSalesOrderShipment().canView) {
      tiles.add(
        _listTile(
          context,
          L10().shipmentsPending,
          TablerIcons.cube_send,
          callback: () {
            _showPendingShipments(context);
          },
        ),
      );
    }

    // Build Orders
    if (homeShowBuild && InvenTreeAPI().checkRole("build", "view")) {
      tiles.add(
        _listTile(
          context,
          "Build Orders", // Using hardcoded string until L10n is implemented for build orders
          TablerIcons.building_factory,
          callback: () {
            _showBuildOrders(context);
          },
          role: "build",
          permission: "view",
        ),
      );
    }

    // Suppliers
    if (homeShowSuppliers && InvenTreePurchaseOrder().canView) {
      tiles.add(
        _listTile(
          context,
          L10().suppliers,
          TablerIcons.building,
          callback: () {
            _showSuppliers(context);
          },
        ),
      );
    }

    // TODO: Add these tiles back in once the features are fleshed out
    /*


    // Manufacturers
    if (homeShowManufacturers) {
      tiles.add(_listTile(
          context,
          L10().manufacturers,
          TablerIcons.building_factory_2,
          callback: () {
            _showManufacturers(context);
          }
      ));
    }
    */
    // Customers
    if (homeShowCustomers) {
      tiles.add(
        _listTile(
          context,
          L10().customers,
          TablerIcons.building_store,
          callback: () {
            _showCustomers(context);
          },
        ),
      );
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
    bool connecting =
        !InvenTreeAPI().isConnected() && InvenTreeAPI().isConnecting();

    Widget leading = Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER);
    Widget trailing = Icon(TablerIcons.server, color: COLOR_ACTION);
    String title = L10().serverNotConnected;
    String subtitle = L10().profileSelectOrCreate;

    if (!validAddress) {
      title = L10().serverNotSelected;
    } else if (connecting) {
      title = L10().serverConnecting;
      subtitle = serverAddress;
      leading = Spinner(icon: TablerIcons.loader_2, color: COLOR_PROGRESS);
    }

    return Center(
      child: Column(
        children: [
          Spacer(),
          Image.asset(
            "assets/image/logo_transparent.png",
            color: Colors.white.withValues(alpha: 0.05),
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
          ),
        ],
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

    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;

    bool smallScreen = max(w, h) < 1000;

    int vTiles = smallScreen ? 2 : 3;
    int hTiles = smallScreen ? 1 : 2;
    double aspect = smallScreen ? 5 : 3;
    double padding = smallScreen ? 2 : 10;

    return GridView.count(
      crossAxisCount: w > h ? vTiles : hTiles,
      children: getListTiles(context),
      childAspectRatio: aspect,
      primary: false,
      crossAxisSpacing: padding,
      mainAxisSpacing: padding,
      padding: EdgeInsets.all(padding),
    );
  }

  @override
  Widget build(BuildContext context) {
    var connected = InvenTreeAPI().isConnected();
    var connecting = !connected && InvenTreeAPI().isConnecting();

    return Scaffold(
      key: homeKey,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/image/logo_transparent.png", height: 24),
            SizedBox(width: 8),
            Text(L10().appTitle),
          ],
        ),
        backgroundColor: COLOR_APP_BAR,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(TablerIcons.server),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: connected
                          ? COLOR_SUCCESS
                          : (connecting ? COLOR_PROGRESS : COLOR_DANGER),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: _selectProfile,
          ),
        ],
      ),
      drawer: InvenTreeDrawer(context),
      body: getBody(context),
      bottomNavigationBar: InvenTreeAPI().isConnected()
          ? buildBottomAppBar(context, homeKey)
          : null,
    );
  }
}
