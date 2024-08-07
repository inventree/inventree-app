
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";


class InvenTreePartSettingsWidget extends StatefulWidget {
  @override
  _InvenTreePartSettingsState createState() => _InvenTreePartSettingsState();
}


class _InvenTreePartSettingsState extends State<InvenTreePartSettingsWidget> {

  _InvenTreePartSettingsState();

  bool partShowParameters = true;
  bool partShowBom = true;
  bool stockShowHistory = false;
  bool stockShowTests = false;
  bool stockConfirmScan = false;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {
    partShowParameters = await InvenTreeSettingsManager().getValue(INV_PART_SHOW_PARAMETERS, true) as bool;
    partShowBom = await InvenTreeSettingsManager().getValue(INV_PART_SHOW_BOM, true) as bool;
    stockShowHistory = await InvenTreeSettingsManager().getValue(INV_STOCK_SHOW_HISTORY, false) as bool;
    stockShowTests = await InvenTreeSettingsManager().getValue(INV_STOCK_SHOW_TESTS, true) as bool;
    stockConfirmScan = await InvenTreeSettingsManager().getValue(INV_STOCK_CONFIRM_SCAN, false) as bool;

    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10().partSettings)),
      body: Container(
        child: ListView(
          children: [
            ListTile(
              title: Text(L10().parameters),
              subtitle: Text(L10().parametersSettingDetail),
              leading: Icon(TablerIcons.list),
              trailing: Switch(
                value: partShowParameters,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_PART_SHOW_PARAMETERS, value);
                  setState(() {
                    partShowParameters = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().bom),
              subtitle: Text(L10().bomEnable),
              leading: Icon(TablerIcons.list),
              trailing: Switch(
                value: partShowBom,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_PART_SHOW_BOM, value);
                  setState(() {
                    partShowBom = value;
                  });
                },
              ),
            ),
            Divider(),
            ListTile(
              title: Text(L10().stockItemHistory),
              subtitle: Text(L10().stockItemHistoryDetail),
              leading: Icon(TablerIcons.history),
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
            ListTile(
              title: Text(L10().testResults),
              subtitle: Text(L10().testResultsDetail),
              leading:  Icon(TablerIcons.test_pipe),
              trailing: Switch(
                value: stockShowTests,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STOCK_SHOW_TESTS, value);
                  setState(() {
                    stockShowTests = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().confirmScan),
              subtitle: Text(L10().confirmScanDetail),
              leading: Icon(TablerIcons.qrcode),
              trailing: Switch(
                value: stockConfirmScan,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STOCK_CONFIRM_SCAN, value);
                  setState(() {
                    stockConfirmScan = value;
                  });
                }
              ),
            )
          ]
        )
      )
    );
  }
}