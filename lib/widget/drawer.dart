import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:package_info_plus/package_info_plus.dart";

import "package:inventree/api.dart";
import "package:inventree/barcode.dart";
import "package:inventree/l10.dart";

import "package:inventree/settings/about.dart";
import "package:inventree/settings/settings.dart";

import "package:inventree/widget/search.dart";


/*
 * Custom "drawer" widget for the InvenTree app.
 *
 * - Provides a "home" button which completely unwinds the widget stack
 * - Global search
 * - Barcoed scan
 */
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

    if (!InvenTreeAPI().checkConnection()) return;

    _closeDrawer();

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SearchWidget(true)
        )
    );
  }

  /*
   * Launch the camera to scan a QR code.
   * Upon successful scan, data are passed off to be decoded.
   */
  Future <void> _scan() async {
    if (!InvenTreeAPI().checkConnection()) return;

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

  /*
   * Load "About" widget
   */
  Future<void> _about() async {
    _closeDrawer();

    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)));
    });
  }

  @override
  Widget build(BuildContext context) {

    return  Drawer(
        child: ListView(
            children: ListTile.divideTiles(
              context: context,
              tiles: <Widget>[
                ListTile(
                  leading: FaIcon(FontAwesomeIcons.house),
                  title: Text(
                    L10().appTitle,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: _home,
                ),
                ListTile(
                  title: Text(L10().scanBarcode),
                  onTap: _scan,
                  leading: Icon(Icons.qr_code_scanner),
                ),
                ListTile(
                  title: Text(L10().search),
                  leading: FaIcon(FontAwesomeIcons.magnifyingGlass),
                  onTap: _search,
                ),
                ListTile(
                  title: Text(L10().settings),
                  leading: Icon(Icons.settings),
                  onTap: _settings,
                ),
                ListTile(
                  title: Text(L10().about),
                  leading: FaIcon(FontAwesomeIcons.circleInfo),
                  onTap: _about,
                )
              ]
            ).toList(),
        )
    );
  }
}