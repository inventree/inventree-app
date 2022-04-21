import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/settings/settings.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/l10.dart";
import "package:inventree/barcode.dart";
import "package:inventree/api.dart";
import "package:inventree/settings/login.dart";
import "package:inventree/widget/category_display.dart";
import "package:inventree/widget/company_list.dart";
import "package:inventree/widget/location_display.dart";
import "package:inventree/widget/part_list.dart";
import "package:inventree/widget/purchase_order_list.dart";
import "package:inventree/widget/search.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/drawer.dart";

import "package:inventree/app_settings.dart";


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

  }

  bool homeShowPo = true;
  bool homeShowSubscribed = true;
  bool homeShowManufacturers = true;
  bool homeShowCustomers = true;
  bool homeShowSuppliers = true;

  final GlobalKey<_InvenTreeHomePageState> _homeKey = GlobalKey<_InvenTreeHomePageState>();

  // Selected user profile
  UserProfile? _profile;

  void _search(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchWidget()
      )
    );

  }

  void _scan(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    scanQrCode(context);
  }

  void _showParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  void _showSettings(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeSettingsWidget()));
  }

  void _showStarredParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

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
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
  }

  void _showPurchaseOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseOrderListWidget(filters: {})
      )
    );
  }


  void _showSuppliers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().suppliers, {"is_supplier": "true"})));
  }

  void _showManufacturers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  void _showCustomers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().customers, {"is_customer": "true"})));
  }

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
          setState(() {});
        });
      }
    }

    setState(() {});
  }


  Widget _iconButton(BuildContext context, String label, IconData icon, {Function()? callback, String role = "", String permission = ""}) {

    bool connected = InvenTreeAPI().isConnected();

    bool allowed = true;

    if (role.isNotEmpty || permission.isNotEmpty) {
      allowed = InvenTreeAPI().checkPermission(role, permission);
    }

    return GestureDetector(
      child: Card(
        margin: EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              color: connected && allowed ? COLOR_CLICK : Colors.grey,
            ),
            Divider(
              height: 15,
              thickness: 0,
              color: Colors.transparent,
            ),
            Text(
              label,
              textAlign: TextAlign.center,
            ),
          ]
        )
      ),
      onTap: () {

        if (!allowed) {
          showSnackIcon(
            L10().permissionRequired,
            icon: FontAwesomeIcons.exclamationCircle,
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

  List<Widget> getGridTiles(BuildContext context) {

    List<Widget> tiles = [];

    // Barcode scanner
    tiles.add(_iconButton(
      context,
      L10().scanBarcode,
      Icons.qr_code_scanner,
      callback: () {
        _scan(context);
      }
    ));

    // Search widget
    tiles.add(_iconButton(
      context,
      L10().search,
      FontAwesomeIcons.search,
      callback: () {
        _search(context);
      }
    ));

    // Parts
    tiles.add(_iconButton(
      context,
      L10().parts,
      FontAwesomeIcons.shapes,
      callback: () {
        _showParts(context);
      }
    ));

    // Starred parts
    if (homeShowSubscribed) {
      tiles.add(_iconButton(
        context,
        L10().partsStarred,
        FontAwesomeIcons.bell,
        callback: () {
          _showStarredParts(context);
        }
      ));
    }

    // Stock button
    tiles.add(_iconButton(
        context,
        L10().stock,
        FontAwesomeIcons.boxes,
        callback: () {
          _showStock(context);
        }
    ));

    // Purchase orderes
    if (homeShowPo) {
      tiles.add(_iconButton(
          context,
          L10().purchaseOrders,
          FontAwesomeIcons.shoppingCart,
          callback: () {
            _showPurchaseOrders(context);
          }
      ));
    }

    // Suppliers
    if (homeShowSuppliers) {
      tiles.add(_iconButton(
          context,
          L10().suppliers,
          FontAwesomeIcons.building,
          callback: () {
            _showSuppliers(context);
          }
      ));
    }

    // Manufacturers
    if (homeShowManufacturers) {
      tiles.add(_iconButton(
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
      tiles.add(_iconButton(
          context,
          L10().customers,
          FontAwesomeIcons.userTie,
          callback: () {
            _showCustomers(context);
          }
      ));
    }

    // Settings
    tiles.add(_iconButton(
        context,
        L10().settings,
        FontAwesomeIcons.cogs,
        callback: () {
          _showSettings(context);
        }
    ));

    return tiles;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      key: _homeKey,
      appBar: AppBar(
        title: Text(L10().appTitle),
        actions: [
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.server,
              color: InvenTreeAPI().isConnected() ? COLOR_SUCCESS : COLOR_DANGER,
            ),
            onPressed: _selectProfile,
          )
        ],
      ),
      drawer: InvenTreeDrawer(context),
      body: ListView(
        children: [
          GridView.extent(
            maxCrossAxisExtent: 140,
            shrinkWrap: true,
            physics: ClampingScrollPhysics(),
            children: getGridTiles(context),
          ),
        ],
      ),
    );
  }
}
