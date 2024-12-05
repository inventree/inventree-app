
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";

import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";


class InvenTreePurchaseOrderSettingsWidget extends StatefulWidget {
  @override
  _InvenTreePurchaseOrderSettingsState createState() => _InvenTreePurchaseOrderSettingsState();
}


class _InvenTreePurchaseOrderSettingsState extends State<InvenTreePurchaseOrderSettingsWidget> {

  _InvenTreePurchaseOrderSettingsState();

  bool poEnable = true;
  bool poShowCamera = true;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {
    poEnable = await InvenTreeSettingsManager().getBool(INV_PO_ENABLE, true);
    poShowCamera = await InvenTreeSettingsManager().getBool(INV_PO_SHOW_CAMERA, true);

    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(L10().purchaseOrderSettings),
          backgroundColor: COLOR_APP_BAR,
        ),
        body: Container(
            child: ListView(
                children: [
                  ListTile(
                    title: Text(L10().purchaseOrderEnable),
                    subtitle: Text(L10().purchaseOrderEnableDetail),
                    leading: Icon(TablerIcons.shopping_cart),
                    trailing: Switch(
                      value: poEnable,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_PO_ENABLE, value);
                        setState(() {
                          poEnable = value;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(L10().purchaseOrderShowCamera),
                    subtitle: Text(L10().purchaseOrderShowCameraDetail),
                    leading: Icon(TablerIcons.camera),
                    trailing: Switch(
                      value: poShowCamera,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_PO_SHOW_CAMERA, value);
                        setState(() {
                          poShowCamera = value;
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