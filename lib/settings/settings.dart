import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/app_settings.dart";
import "package:inventree/settings/home_settings.dart";
import "package:inventree/settings/login.dart";
import "package:inventree/settings/part_settings.dart";


class InvenTreeSettingsWidget extends StatefulWidget {
  // InvenTree settings view

  @override
  _InvenTreeSettingsState createState() => _InvenTreeSettingsState();

}


class _InvenTreeSettingsState extends State<InvenTreeSettingsWidget> {

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(L10().settings),
      ),
      body: Center(
        child: ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: <Widget>[
              ListTile(
                  title: Text(L10().server),
                  subtitle: Text(L10().configureServer),
                  leading: FaIcon(FontAwesomeIcons.server, color: COLOR_CLICK),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget()));
                  },
              ),
              ListTile(
                title: Text(L10().homeScreen),
                subtitle: Text(L10().homeScreenSettings),
                leading: FaIcon(FontAwesomeIcons.house, color: COLOR_CLICK),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreenSettingsWidget()));
                }
              ),
              ListTile(
                title: Text(L10().appSettings),
                subtitle: Text(L10().appSettingsDetails),
                leading: FaIcon(FontAwesomeIcons.gears, color: COLOR_CLICK),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeAppSettingsWidget()));
                }
              ),
              ListTile(
                title: Text(L10().part),
                subtitle: Text(L10().partSettings),
                leading: FaIcon(FontAwesomeIcons.shapes, color: COLOR_CLICK),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreePartSettingsWidget()));
                }
              )
            ]
          ).toList()
        )
      )
    );
  }
}