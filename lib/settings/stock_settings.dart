import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";

class InvenTreeStockSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeStockSettingsState createState() => _InvenTreeStockSettingsState();
}

class _InvenTreeStockSettingsState extends State<InvenTreeStockSettingsWidget> {
  _InvenTreeStockSettingsState();

  bool stockShowHistory = false;
  bool stockShowTests = false;
  bool stockConfirmScan = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
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
        title: Text(L10().stockSettings),
        backgroundColor: COLOR_APP_BAR,
      ),
      body: Container(
        child: ListView(
          children: [
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
