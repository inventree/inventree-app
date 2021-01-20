import 'package:InvenTree/api.dart';
import 'package:InvenTree/barcode.dart';
import 'package:InvenTree/widget/company_list.dart';
import 'package:InvenTree/widget/search.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/location_display.dart';

import 'package:InvenTree/settings/settings.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class InvenTreeDrawer extends StatelessWidget {

  final BuildContext context;

  InvenTreeDrawer(this.context);

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

    Navigator.pushNamedAndRemoveUntil(context, "/", (r) => false);
  }

  void _search() {
    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => SearchWidget()));
  }

  /*
   * Launch the camera to scan a QR code.
   * Upon successful scan, data are passed off to be decoded.
   */
  void _scan() async {
    if (!InvenTreeAPI().checkConnection(context)) return;

    _closeDrawer();
    scanQrCode(context);
  }

  /*
   * Display the top-level PartCategory list
   */
  void _showParts() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  /*
   * Display the top-level StockLocation list
   */
  void _showStock() {
    if (!InvenTreeAPI().checkConnection(context)) return;
    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
  }

  void _showSuppliers() {
    if (!InvenTreeAPI().checkConnection(context)) return;
    _closeDrawer();

    Navigator.push(context, MaterialPageRoute(builder: (context) => SupplierListWidget()));
  }

  void _showManufacturers() {
    if (!InvenTreeAPI().checkConnection(context)) return;
    _closeDrawer();

    Navigator.push(context, MaterialPageRoute(builder: (context) => ManufacturerListWidget()));
  }

  void _showCustomers() {
    if (!InvenTreeAPI().checkConnection(context)) return;
    _closeDrawer();

    Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerListWidget()));
  }

  /*
   * Load settings widget
   */
  void _settings() {
    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeSettingsWidget()));
  }

  @override
  Widget build(BuildContext context) {
    return  Drawer(
        child: new ListView(
            children: <Widget>[
              new ListTile(
                leading: new Image.asset(
                  "assets/image/icon.png",
                  fit: BoxFit.scaleDown,
                  width: 40,
                ),
                title: new Text("InvenTree"),
                onTap: _home,
              ),
              new Divider(),
              /*
              // TODO - Add search functionality!
              new ListTile(
                title: new Text("Search"),
                leading: new FaIcon(FontAwesomeIcons.search),
                onTap: _search,
              ),
              */
              new ListTile(
                title: new Text("Scan Barcode"),
                onTap: _scan,
                leading: new FaIcon(FontAwesomeIcons.barcode),
              ),
              new Divider(),
              new ListTile(
                title: new Text("Parts"),
                leading: new Icon(Icons.category),
                onTap: _showParts,
              ),
              new ListTile(
                title: new Text("Stock"),
                leading: new FaIcon(FontAwesomeIcons.boxes),
                onTap: _showStock,
              ),
              /*
              new ListTile(
                title: new Text("Suppliers"),
                leading: new FaIcon(FontAwesomeIcons.building),
                onTap: _showSuppliers,
              ),
              new ListTile(
                title: Text("Manufacturers"),
                leading: new FaIcon(FontAwesomeIcons.industry),
                  onTap: _showManufacturers,
              ),
              new ListTile(
                title: new Text("Customers"),
                leading: new FaIcon(FontAwesomeIcons.users),
                onTap: _showCustomers,
              ),
              */
              new Divider(),
              new ListTile(
                title: new Text("Settings"),
                leading: new Icon(Icons.settings),
                onTap: _settings,
              ),
            ]
        )
    );
  }
}