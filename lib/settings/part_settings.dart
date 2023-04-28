
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
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

    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10().part)),
      body: Container(
        child: ListView(
          children: [
            ListTile(
              title: Text(L10().parameters),
              subtitle: Text(L10().parametersSettingDetail),
              leading: FaIcon(FontAwesomeIcons.tableList),
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
              leading: FaIcon(FontAwesomeIcons.list),
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
            ListTile(
              title: Text(L10().stockItemHistory),
              subtitle: Text(L10().stockItemHistoryDetail),
              leading: FaIcon(FontAwesomeIcons.clockRotateLeft),
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
              leading:  FaIcon(FontAwesomeIcons.vial),
              trailing: Switch(
                value: stockShowTests,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STOCK_SHOW_TESTS, value);
                  setState(() {
                    stockShowTests = value;
                  });
                },
              ),
            )
          ]
        )
      )
    );
  }
}