import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/preferences.dart";

class InvenTreePartSettingsWidget extends StatefulWidget {
  @override
  _InvenTreePartSettingsState createState() => _InvenTreePartSettingsState();
}

class _InvenTreePartSettingsState extends State<InvenTreePartSettingsWidget> {
  _InvenTreePartSettingsState();

  bool partShowBom = true;
  bool partShowPricing = true;
  bool stockShowHistory = false;
  bool stockShowTests = false;
  bool stockConfirmScan = false;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {

    partShowBom = await InvenTreeSettingsManager().getBool(
      INV_PART_SHOW_BOM,
      true,
    );
    partShowPricing = await InvenTreeSettingsManager().getBool(
      INV_PART_SHOW_PRICING,
      true,
    );
    stockShowHistory = await InvenTreeSettingsManager().getBool(
      INV_STOCK_SHOW_HISTORY,
      false,
    );
    stockShowTests = await InvenTreeSettingsManager().getBool(
      INV_STOCK_SHOW_TESTS,
      true,
    );
    stockConfirmScan = await InvenTreeSettingsManager().getBool(
      INV_STOCK_CONFIRM_SCAN,
      false,
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().partSettings),
        backgroundColor: COLOR_APP_BAR,
      ),
      body: Container(
        child: ListView(
          children: [
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
            ListTile(
              title: Text(L10().partPricing),
              subtitle: Text(L10().partPricingSettingDetail),
              leading: Icon(TablerIcons.currency_dollar),
              trailing: Switch(
                value: partShowPricing,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(
                    INV_PART_SHOW_PRICING,
                    value,
                  );
                  setState(() {
                    partShowPricing = value;
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
                  InvenTreeSettingsManager().setValue(
                    INV_STOCK_SHOW_HISTORY,
                    value,
                  );
                  setState(() {
                    stockShowHistory = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().testResults),
              subtitle: Text(L10().testResultsDetail),
              leading: Icon(TablerIcons.test_pipe),
              trailing: Switch(
                value: stockShowTests,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(
                    INV_STOCK_SHOW_TESTS,
                    value,
                  );
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
                  InvenTreeSettingsManager().setValue(
                    INV_STOCK_CONFIRM_SCAN,
                    value,
                  );
                  setState(() {
                    stockConfirmScan = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
