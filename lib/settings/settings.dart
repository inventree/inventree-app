import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
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
        backgroundColor: COLOR_APP_BAR,
      ),
      body: Center(
        child: ListView(
          children: [
              ListTile(
                  title: Text(L10().server),
                  subtitle: Text(L10().configureServer),
                  leading: Icon(TablerIcons.server, color: COLOR_ACTION),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeSelectServerWidget()));
                  },
              ),
              ListTile(
                  title: Text(L10().appSettings),
                  subtitle: Text(L10().appSettingsDetails),
                  leading: Icon(TablerIcons.settings, color: COLOR_ACTION),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeAppSettingsWidget()));
                  }
              ),
              ListTile(
                title: Text(L10().homeScreen),
                subtitle: Text(L10().homeScreenSettings),
                leading: Icon(TablerIcons.home, color: COLOR_ACTION),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreenSettingsWidget()));
                }
              ),
              ListTile(
                title: Text(L10().barcodes),
                subtitle: Text(L10().barcodeSettings),
                leading: Icon(TablerIcons.barcode, color: COLOR_ACTION),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeBarcodeSettingsWidget()));
                }
              ),
              ListTile(
                title: Text(L10().part),
                subtitle: Text(L10().partSettings),
                leading: Icon(TablerIcons.box, color: COLOR_ACTION),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreePartSettingsWidget()));
                }
              ),
              Divider(),
              ListTile(
                title: Text(L10().about),
                leading: Icon(TablerIcons.info_circle, color: COLOR_ACTION),
                onTap: _about,
              )
            ]
        )
      )
    );
  }
}