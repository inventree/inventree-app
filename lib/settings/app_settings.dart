
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:inventree/l10.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:inventree/app_settings.dart';

class InvenTreeAppSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeAppSettingsState createState() => _InvenTreeAppSettingsState();
}

class _InvenTreeAppSettingsState extends State<InvenTreeAppSettingsWidget> {

  final GlobalKey<_InvenTreeAppSettingsState> _settingsKey = GlobalKey<_InvenTreeAppSettingsState>();

  _InvenTreeAppSettingsState();

  bool barcodeSounds = true;
  bool serverSounds = true;
  bool partSubcategory = false;
  bool stockSublocation = false;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  void loadSettings() async {
    barcodeSounds = await InvenTreeSettingsManager().getValue("barcodeSounds", true) as bool;
    serverSounds = await InvenTreeSettingsManager().getValue("serverSounds", true) as bool;

    partSubcategory = await InvenTreeSettingsManager().getValue("partSubcategory", false) as bool;
    stockSublocation = await InvenTreeSettingsManager().getValue("stockSublocation", false) as bool;

    setState(() {
    });
  }

  void setBarcodeSounds(bool en) async {

    await InvenTreeSettingsManager().setValue("barcodeSounds", en);
    barcodeSounds = await InvenTreeSettingsManager().getValue("barcodeSounds", true);

    setState(() {
    });
  }

  void setServerSounds(bool en) async {

    await InvenTreeSettingsManager().setValue("serverSounds", en);
    serverSounds = await InvenTreeSettingsManager().getValue("serverSounds", true);

    setState(() {
    });
  }

  void setPartSubcategory(bool en) async {
    await InvenTreeSettingsManager().setValue("partSubcategory", en);
    partSubcategory = await InvenTreeSettingsManager().getValue("partSubcategory", false);

    setState(() {
    });
  }

  void setStockSublocation(bool en) async {
    await InvenTreeSettingsManager().setValue("stockSublocation", en);
    stockSublocation = await InvenTreeSettingsManager().getValue("stockSublocation", false);

    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      key: _settingsKey,
      appBar: AppBar(
        title: Text(L10().appSettings),
      ),
      body: Container(
        child: ListView(
          children: [
            ListTile(
              title: Text(
                L10().parts,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.shapes),
            ),
            ListTile(
              title: Text(L10().includeSubcategories),
              subtitle: Text(L10().includeSubcategoriesDetail),
              leading: FaIcon(FontAwesomeIcons.sitemap),
              trailing: Switch(
                value: partSubcategory,
                onChanged: setPartSubcategory,
              ),
            ),
            Divider(height: 3),
            ListTile(
              title: Text(L10().stock,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.boxes),
            ),
            ListTile(
              title: Text(L10().includeSublocations),
              subtitle: Text(L10().includeSublocationsDetail),
              leading: FaIcon(FontAwesomeIcons.sitemap),
              trailing: Switch(
                value: stockSublocation,
                onChanged: setStockSublocation,
              ),
            ),
            Divider(height: 3),
            ListTile(
              title: Text(
                L10().sounds,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.volumeUp),
            ),
            ListTile(
              title: Text(L10().serverError),
              subtitle: Text(L10().soundOnServerError),
              leading: FaIcon(FontAwesomeIcons.server),
              trailing: Switch(
                value: serverSounds,
                onChanged: setServerSounds,
              ),
            ),
            ListTile(
              title: Text(L10().barcodeTones),
              subtitle: Text(L10().soundOnBarcodeAction),
              leading: FaIcon(FontAwesomeIcons.qrcode),
              trailing: Switch(
                value: barcodeSounds,
                onChanged: setBarcodeSounds,
              ),
            ),
            Divider(height: 1),
          ]
        )
      )
    );
  }
}