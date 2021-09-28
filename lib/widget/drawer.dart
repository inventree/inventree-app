import "package:inventree/api.dart";
import "package:inventree/barcode.dart";
import "package:inventree/widget/search.dart";
import "package:flutter/material.dart";
import "package:inventree/l10.dart";

import "package:inventree/widget/category_display.dart";
import "package:inventree/widget/location_display.dart";

import "package:inventree/settings/settings.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

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

    Navigator.pushNamedAndRemoveUntil(context, "/", (r) => false);
  }

  void _search() {

    if (!InvenTreeAPI().checkConnection(context)) return;

    _closeDrawer();

    showSearch(
      context: context,
      delegate: PartSearchDelegate(context)
    );

    //Navigator.push(context, MaterialPageRoute(builder: (context) => SearchWidget()));
  }

  /*
   * Launch the camera to scan a QR code.
   * Upon successful scan, data are passed off to be decoded.
   */
  Future <void> _scan() async {
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

  /*
  void _showSuppliers() {
    if (!InvenTreeAPI().checkConnection(context)) return;
    _closeDrawer();

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().suppliers, {"is_supplier": "true"})));
  }

  void _showManufacturers() {
    if (!InvenTreeAPI().checkConnection(context)) return;
    _closeDrawer();

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  void _showCustomers() {
    if (!InvenTreeAPI().checkConnection(context)) return;
    _closeDrawer();

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().customers, {"is_customer": "true"})));
  }
   */

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
        child: ListView(
            children: ListTile.divideTiles(
              context: context,
              tiles: <Widget>[
                ListTile(
                  leading: Image.asset(
                    "assets/image/icon.png",
                    fit: BoxFit.scaleDown,
                    width: 30,
                  ),
                  title: Text(
                    L10().appTitle,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: _home,
                ),
                ListTile(
                  title: Text(L10().scanBarcode),
                  onTap: _scan,
                  leading: FaIcon(FontAwesomeIcons.barcode),
                ),
                ListTile(
                  title: Text(L10().search),
                  leading: FaIcon(FontAwesomeIcons.search),
                  onTap: _search,
                ),
                ListTile(
                  title: Text(L10().parts),
                  leading: Icon(Icons.category),
                  onTap: _showParts,
                ),
                ListTile(
                  title: Text(L10().stock),
                  leading: FaIcon(FontAwesomeIcons.boxes),
                  onTap: _showStock,
                ),

                /*
                ListTile(
                  title: Text("Suppliers"),
                  leading: FaIcon(FontAwesomeIcons.building),
                  onTap: _showSuppliers,
                ),
                ListTile(
                  title: Text("Manufacturers"),
                  leading: FaIcon(FontAwesomeIcons.industry),
                    onTap: _showManufacturers,
                ),
                ListTile(
                  title: Text("Customers"),
                  leading: FaIcon(FontAwesomeIcons.users),
                  onTap: _showCustomers,
                ),
                */

                ListTile(
                  title: Text(L10().settings),
                  leading: Icon(Icons.settings),
                  onTap: _settings,
                ),
              ]
            ).toList(),
        )
    );
  }
}