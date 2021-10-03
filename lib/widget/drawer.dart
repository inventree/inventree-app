import "package:inventree/api.dart";
import "package:inventree/barcode.dart";
import "package:flutter/material.dart";
import "package:inventree/l10.dart";

import "package:inventree/settings/settings.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/widget/search.dart";

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

  void _search() {

    if (!InvenTreeAPI().checkConnection(context)) return;

    _closeDrawer();

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SearchWidget()
        )
    );
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
                  leading: FaIcon(FontAwesomeIcons.home),
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