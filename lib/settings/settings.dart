import 'package:InvenTree/settings/about.dart';
import 'package:InvenTree/settings/login.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:InvenTree/api.dart';
import 'login.dart';

import 'package:package_info/package_info.dart';

class InvenTreeSettingsWidget extends StatefulWidget {
  // InvenTree settings view

  @override
  _InvenTreeSettingsState createState() => _InvenTreeSettingsState();

}


class _InvenTreeSettingsState extends State<InvenTreeSettingsWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("InvenTree Settings"),
      ),
      body: Center(
        child: ListView(
          children: <Widget>[
            ListTile(
                title: Text("Server Settings"),
                subtitle: Text("Configure server and login settings"),
                onTap: _editServerSettings,
            ),
            Divider(),
            ListTile(
              title: Text("About"),
              subtitle: Text("App details"),
              onTap: _about,
            ),
          ],
        )
      )
    );
  }

  void _editServerSettings() async {

    var prefs = await SharedPreferences.getInstance();

    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget(prefs)));
  }

  void _about() async {

    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)));
    });
  }
}