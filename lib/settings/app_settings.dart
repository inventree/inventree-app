
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class InvenTreeAppSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeAppSettingsState createState() => _InvenTreeAppSettingsState();
}

class _InvenTreeAppSettingsState extends State<InvenTreeAppSettingsWidget> {

  final GlobalKey<_InvenTreeAppSettingsState> _settingsKey = GlobalKey<_InvenTreeAppSettingsState>();

  _InvenTreeAppSettingsState() {

  }

  bool a = false;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      key: _settingsKey,
      appBar: AppBar(
        title: Text(I18N.of(context).appSettings),
      ),
      body: Container(
        child: ListView(
          children: [
            ListTile(
              title: Text(
                "Sounds",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.volumeUp),
            ),
            ListTile(
              title: Text("Server Error"),
              subtitle: Text("Play audible tone on server error"),
              leading: FaIcon(FontAwesomeIcons.server),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  setState(() {
                    // TODO
                  });
                },
              ),
            ),
            ListTile(
              title: Text("Barcode Tones"),
              subtitle: Text("Play audible tones for barcode actions"),
              leading: FaIcon(FontAwesomeIcons.qrcode),
              trailing: Switch(
                value: a,
                onChanged: (value) {
                  setState(() {
                    a = value;
                  });
                },
              ),
            ),
            Divider(height: 1),
          ]
        )
      )
    );
  }
}