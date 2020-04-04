import 'package:InvenTree/barcode.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/location_display.dart';

import 'package:InvenTree/settings.dart';

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

  /*
   * Launch the camera to scan a QR code.
   * Upon successful scan, data are passed off to be decoded.
   */
  void _scan() async {

    _closeDrawer();
    scanQrCode(context);
  }

  /*
   * Display the top-level PartCategory list
   */
  void _showParts() {

    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  /*
   * Display the top-level StockLocation list
   */
  void _showStock() {
    _closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
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
                ),
                title: new Text("InvenTree"),
                onTap: _home,
              ),
              new Divider(),
              new ListTile(
                title: new Text("Search"),
                leading: new Icon(Icons.search),
                onTap: null,
              ),
              new ListTile(
                title: new Text("Scan"),
                onTap: _scan,
                leading: new Icon(Icons.search),
              ),
              new Divider(),
              new ListTile(
                title: new Text("Parts"),
                leading: new Icon(Icons.category),
                onTap: _showParts,
              ),
              new ListTile(
                title: new Text("Stock"),
                onTap: _showStock,
              ),
              new ListTile(
                title: new Text("Suppliers"),
                leading: new Icon(Icons.business),
                onTap: null,
              ),
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