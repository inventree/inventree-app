import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:package_info_plus/package_info_plus.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/settings/about.dart";
import "package:inventree/settings/app_settings.dart";
import "package:inventree/settings/barcode_settings.dart";
import "package:inventree/settings/home_settings.dart";
import "package:inventree/settings/select_server.dart";
import "package:inventree/settings/part_settings.dart";


// InvenTree settings view
class InvenTreeSettingsWidget extends StatefulWidget {

  @override
  _InvenTreeSettingsState createState() => _InvenTreeSettingsState();

}


class _InvenTreeSettingsState extends State<InvenTreeSettingsWidget> {

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /*
   * Load "About" widget
   */
  Future<void> _about() async {
    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(L10().settings),
      ),
      body: Center(
        child: ListView(
          children: [
              ListTile(
                  title: Text(L10().server),
                  subtitle: Text(L10().configureServer),
                  leading: FaIcon(FontAwesomeIcons.server, color: COLOR_ACTION),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeSelectServerWidget()));
                  },
              ),
              ListTile(
                  title: Text(L10().appSettings),
                  subtitle: Text(L10().appSettingsDetails),
                  leading: FaIcon(FontAwesomeIcons.gears, color: COLOR_ACTION),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeAppSettingsWidget()));
                  }
              ),
              ListTile(
                title: Text(L10().homeScreen),
                subtitle: Text(L10().homeScreenSettings),
                leading: FaIcon(FontAwesomeIcons.house, color: COLOR_ACTION),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreenSettingsWidget()));
                }
              ),
              ListTile(
                title: Text(L10().barcodes),
                subtitle: Text(L10().barcodeSettings),
                leading: FaIcon(FontAwesomeIcons.barcode, color: COLOR_ACTION),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeBarcodeSettingsWidget()));
                }
              ),
              ListTile(
                title: Text(L10().part),
                subtitle: Text(L10().partSettings),
                leading: FaIcon(FontAwesomeIcons.shapes, color: COLOR_ACTION),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreePartSettingsWidget()));
                }
              ),
              Divider(),
              ListTile(
                title: Text(L10().about),
                leading: FaIcon(FontAwesomeIcons.circleInfo, color: COLOR_ACTION),
                onTap: _about,
              )
            ]
        )
      )
    );
  }
}