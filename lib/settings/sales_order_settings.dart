
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/preferences.dart";


class InvenTreeSalesOrderSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeSalesOrderSettingsState createState() => _InvenTreeSalesOrderSettingsState();
}


class _InvenTreeSalesOrderSettingsState extends State<InvenTreeSalesOrderSettingsWidget> {

  _InvenTreeSalesOrderSettingsState();

  bool soEnable = true;
  bool soShowCamera = true;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {
    soEnable = await InvenTreeSettingsManager().getBool(INV_SO_ENABLE, true);
    soShowCamera = await InvenTreeSettingsManager().getBool(INV_SO_SHOW_CAMERA, true);

    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(L10().salesOrderSettings),
          backgroundColor: COLOR_APP_BAR,
        ),
        body: Container(
            child: ListView(
                children: [
                  ListTile(
                    title: Text(L10().salesOrderEnable),
                    subtitle: Text(L10().salesOrderEnableDetail),
                    leading: Icon(TablerIcons.shopping_cart),
                    trailing: Switch(
                      value: soEnable,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_SO_ENABLE, value);
                        setState(() {
                          soEnable = value;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(L10().salesOrderShowCamera),
                    subtitle: Text(L10().salesOrderShowCameraDetail),
                    leading: Icon(TablerIcons.camera),
                    trailing: Switch(
                      value: soShowCamera,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_SO_SHOW_CAMERA, value);
                        setState(() {
                          soShowCamera = value;
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