import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";


class InvenTreeBarcodeSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeBarcodeSettingsState createState() => _InvenTreeBarcodeSettingsState();
}


class _InvenTreeBarcodeSettingsState extends State<InvenTreeBarcodeSettingsWidget> {

 _InvenTreeBarcodeSettingsState();

 int barcodeScanDelay = 500;

 final TextEditingController _barcodeScanDelayController = TextEditingController();

 @override
 void initState() {
  super.initState();
  loadSettings();
 }

  Future<void> loadSettings() async {
    barcodeScanDelay = await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_DELAY, 500) as int;

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
    return Scaffold(
      appBar: AppBar(title: Text(L10().barcodes)),
      body: Container(
        child: ListView(
          children: [
            ListTile(
              title: Text(L10().barcodeScanDelay),
              subtitle: Text(L10().barcodeScanDelayDetail),
              leading: FaIcon(FontAwesomeIcons.stopwatch),
              trailing: GestureDetector(
                child: Text("${barcodeScanDelay} ms"),
                onTap: () {
                  _editBarcodeScanDelay(context);
                },
              ),
            )
          ],
        )
      )
    );
  }

}