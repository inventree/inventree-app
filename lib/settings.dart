import 'package:flutter/material.dart';

import 'login_settings.dart';

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
          ],
        )
      )
    );
  }

  void _editServerSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget()));
  }
}