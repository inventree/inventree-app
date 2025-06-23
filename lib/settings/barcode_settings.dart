import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";
import "package:inventree/app_colors.dart";

import "package:inventree/widget/dialogs.dart";


class InvenTreeBarcodeSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeBarcodeSettingsState createState() => _InvenTreeBarcodeSettingsState();
}


class _InvenTreeBarcodeSettingsState extends State<InvenTreeBarcodeSettingsWidget> {

 _InvenTreeBarcodeSettingsState();

 int barcodeScanDelay = 500;
 int barcodeScanType = BARCODE_CONTROLLER_CAMERA;
 bool barcodeScanSingle = false;

 final TextEditingController _barcodeScanDelayController = TextEditingController();

 @override
 void initState() {
  super.initState();
  loadSettings();
 }

  Future<void> loadSettings() async {
    barcodeScanDelay = await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_DELAY, 500) as int;
    barcodeScanType = await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_TYPE, BARCODE_CONTROLLER_CAMERA) as int;
    barcodeScanSingle = await InvenTreeSettingsManager().getBool(INV_BARCODE_SCAN_SINGLE, false);

    if (mounted) {
      setState(() {
      });
    }
  }

  // Callback function to edit the barcode scan delay value
  // TODO: Next time any new settings are added, refactor this into a generic function
  Future<void> _editBarcodeScanDelay(BuildContext context) async {

    _barcodeScanDelayController.text = barcodeScanDelay.toString();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(L10().barcodeScanDelay),
          content: TextField(
            onChanged: (value) {},
            controller: _barcodeScanDelayController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: L10().barcodeScanDelayDetail,
            ),
          ),
          actions: <Widget>[
            MaterialButton(
              color: Colors.red,
              textColor: Colors.white,
              child: Text(L10().cancel),
              onPressed: () {
                setState(() {
                  Navigator.pop(context);
                });
              },
            ),
            MaterialButton(
              color: Colors.green,
              textColor: Colors.white,
              child: Text(L10().ok),
              onPressed: () async {
                int delay = int.tryParse(_barcodeScanDelayController.text) ?? barcodeScanDelay;

                // Apply limits
                if (delay < 100) delay = 100;
                if (delay > 2500) delay = 2500;

                InvenTreeSettingsManager().setValue(INV_BARCODE_SCAN_DELAY, delay);
                setState(() {
                  barcodeScanDelay = delay;
                  Navigator.pop(context);
                });
              },
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {

    // Construct an icon for the barcode scanner input
    Widget? barcodeInputIcon;

    switch (barcodeScanType) {
      case BARCODE_CONTROLLER_WEDGE:
        barcodeInputIcon = Icon(Icons.barcode_reader);
      case BARCODE_CONTROLLER_CAMERA:
      default:
        barcodeInputIcon = Icon(TablerIcons.camera);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(L10().barcodeSettings),
        backgroundColor: COLOR_APP_BAR
      ),
      body: Container(
        child: ListView(
          children: [
            ListTile(
              title: Text(L10().barcodeScanController),
              subtitle: Text(L10().barcodeScanControllerDetail),
              leading: Icon(Icons.qr_code_scanner),
              trailing: barcodeInputIcon,
              onTap: () async {
                choiceDialog(
                  L10().barcodeScanController,
                  [
                    ListTile(
                      title: Text(L10().cameraInternal),
                      subtitle: Text(L10().cameraInternalDetail),
                      leading: Icon(TablerIcons.camera),
                    ),
                    ListTile(
                      title: Text(L10().scannerExternal),
                      subtitle: Text(L10().scannerExternalDetail),
                      leading: Icon(Icons.barcode_reader),
                    )
                  ],
                  onSelected: (idx) async {
                    barcodeScanType = idx as int;
                    InvenTreeSettingsManager().setValue(INV_BARCODE_SCAN_TYPE, barcodeScanType);
                    if (mounted) {
                      setState(() {});
                    }
                  }
                );
              }
            ),
            ListTile(
              title: Text(L10().barcodeScanDelay),
              subtitle: Text(L10().barcodeScanDelayDetail),
              leading: Icon(TablerIcons.hourglass),
              trailing: GestureDetector(
                child: Text("${barcodeScanDelay} ms"),
                onTap: () {
                  _editBarcodeScanDelay(context);
                },
              ),
            ),
            ListTile(
              title: Text(L10().barcodeScanSingle),
              subtitle: Text(L10().barcodeScanSingleDetail),
              leading: Icon(Icons.barcode_reader),
              trailing: Switch(
                value: barcodeScanSingle,
                onChanged: (bool v) {
                  InvenTreeSettingsManager().setValue(INV_BARCODE_SCAN_SINGLE, v);
                  setState(() {
                    barcodeScanSingle = v;
                  });
                },
              ),
            )
          ],
        )
      )
    );
  }

}