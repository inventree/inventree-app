import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:InvenTree/api.dart';
import 'login_settings.dart';

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
      showDialog(
        context: context,
        child: new SimpleDialog(
            title: new Text("About InvenTree"),
            children: <Widget>[
              ListTile(
                title: Text("Server Version"),
                subtitle: Text(InvenTreeAPI().version.isNotEmpty ? InvenTreeAPI().version : "Not connected"),
              ),
              Divider(),
              ListTile(
                title: Text("App Name"),
                subtitle: Text("${info.appName}"),
              ),
              ListTile(
                title: Text("Package Name"),
                subtitle: Text("${info.packageName}"),
              ),
              ListTile(
                title: Text("App Version"),
                subtitle: Text("${info.version}"),
              ),
              ListTile(
                title: Text("Build Number"),
                subtitle: Text("${info.buildNumber}")
              ),
              Divider(),
              ListTile(
                title: Text("Submit Bug Report"),
                subtitle: Text("Submit a bug report or feature request at:\n https://github.com/inventree/inventree-app/issues/"),
              )
            ]
        ),
      );
    });
  }
}