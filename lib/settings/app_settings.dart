
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";


class InvenTreeAppSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeAppSettingsState createState() => _InvenTreeAppSettingsState();
}

class _InvenTreeAppSettingsState extends State<InvenTreeAppSettingsWidget> {

  _InvenTreeAppSettingsState();

  final GlobalKey<_InvenTreeAppSettingsState> _settingsKey = GlobalKey<_InvenTreeAppSettingsState>();

  // Sound settings
  bool barcodeSounds = true;
  bool serverSounds = true;

  // Part settings
  bool partSubcategory = false;

  // Stock settings
  bool stockSublocation = false;
  bool stockShowHistory = false;

  bool reportErrors = true;
  bool strictHttps = false;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future <void> loadSettings() async {

    // Load initial settings

    barcodeSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;
    serverSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_SERVER, true) as bool;

    partSubcategory = await InvenTreeSettingsManager().getValue(INV_PART_SUBCATEGORY, true) as bool;

    stockSublocation = await InvenTreeSettingsManager().getValue(INV_STOCK_SUBLOCATION, true) as bool;
    stockShowHistory = await InvenTreeSettingsManager().getValue(INV_STOCK_SHOW_HISTORY, false) as bool;

    reportErrors = await InvenTreeSettingsManager().getValue(INV_REPORT_ERRORS, true) as bool;
    strictHttps = await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false) as bool;

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
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_PART_SUBCATEGORY, value);
                  setState(() {
                    partSubcategory = value;
                  });
                },
              ),
            ),
            /* Stock Settings */
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
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STOCK_SUBLOCATION, value);
                  setState(() {
                    stockSublocation = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().stockItemHistory),
              subtitle: Text(L10().stockItemHistoryDetail),
              leading: FaIcon(FontAwesomeIcons.history),
              trailing: Switch(
                value: stockShowHistory,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STOCK_SHOW_HISTORY, value);
                  setState(() {
                    stockShowHistory = value;
                  });
                },
              ),
            ),
            /* Sound Settings */
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
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_SOUNDS_SERVER, value);
                  setState(() {
                    serverSounds = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().barcodeTones),
              subtitle: Text(L10().soundOnBarcodeAction),
              leading: Icon(Icons.qr_code),
              trailing: Switch(
                value: barcodeSounds,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_SOUNDS_BARCODE, value);
                  setState(() {
                    barcodeSounds = value;
                  });
                },
              ),
            ),
            Divider(height: 1),
            ListTile(
              title: Text(
                L10().appSettings,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.mobile),
            ),
            ListTile(
              title: Text(L10().strictHttps),
              subtitle: Text(L10().strictHttpsDetails),
              leading: FaIcon(FontAwesomeIcons.lock),
              trailing: Switch(
                value: strictHttps,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STRICT_HTTPS, value);
                  setState(() {
                    strictHttps = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().errorReportUpload),
              subtitle: Text(L10().errorReportUploadDetails),
              leading: FaIcon(FontAwesomeIcons.bug),
              trailing: Switch(
                value: reportErrors,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_REPORT_ERRORS, value);
                  setState(() {
                    reportErrors = value;
                  });
                },
              ),
            ),
          ]
        )
      )
    );
  }
}