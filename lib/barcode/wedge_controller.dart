
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/flutter_barcode_listener.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";

/*
 * Barcode controller which acts as a keyboard wedge,
 * intercepting barcode data which is entered as rapid keyboard presses
 */
class WedgeBarcodeController extends InvenTreeBarcodeController {

  const WedgeBarcodeController(BarcodeHandler handler, {Key? key}) : super(handler, key: key);

  @override
  State<StatefulWidget> createState() => _WedgeBarcodeControllerState();

}


class _WedgeBarcodeControllerState extends InvenTreeBarcodeControllerState {

  _WedgeBarcodeControllerState() : super();

  bool canScan = true;

  bool get scanning => mounted && canScan;

  @override
  Future<void> pauseScan() async {

    if (mounted) {
      setState(() {
        canScan = false;
      });
    }
  }

  @override
  Future<void> resumeScan() async {

    if (mounted) {
      setState(() {
        canScan = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(L10().scanBarcode),
      ),
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(flex: 5),
            FaIcon(FontAwesomeIcons.barcode, size: 64),
            Spacer(flex: 5),
            BarcodeKeyboardListener(
              useKeyDownEvent: true,
              child: SizedBox(
                child: CircularProgressIndicator(
                  color: scanning ? COLOR_ACTION : COLOR_PROGRESS
                ),
                width: 64,
                height: 64,
              ),
              onBarcodeScanned: (String barcode) {
                debug("scanned: ${barcode}");
                if (scanning) {
                  // Process the barcode data
                  handleBarcodeData(barcode);
                }
              },
            ),
            Spacer(flex: 5),
            Padding(
              child: Text(
                widget.handler.getOverlayText(context),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white)
              ),
              padding: EdgeInsets.all(20),
            )
          ],
        )
      )
    );
  }

}