
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/handler.dart";

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

  final FocusNode _focusNode = FocusNode();

  List<String> _scannedCharacters = [];

  DateTime? _lastScanTime;

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

  // Callback for a single key press / scan
  void handleKeyEvent(KeyEvent event) {

    if (!scanning) {
      return;
    }

    // Look only for key-down events
    if (event is! KeyDownEvent) {
      return;
    }

    // Ignore events without a character code
    if (event.character == null) {
      return;
    }

    DateTime now = DateTime.now();

    // Throw away old characters
    if (_lastScanTime == null || _lastScanTime!.isBefore(now.subtract(Duration(milliseconds: 250)))) {
      _scannedCharacters.clear();
    }

    _lastScanTime = now;

    if (event.character == "\n") {
      if (_scannedCharacters.isNotEmpty) {
        // Debug output required for unit testing
        debug("scanned: ${_scannedCharacters.join()}");
        handleBarcodeData(_scannedCharacters.join());
      }

      _scannedCharacters.clear();
    } else {
      _scannedCharacters.add(event.character!);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: COLOR_APP_BAR,
        title: Text(L10().scanBarcode),
      ),
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(flex: 5),
            Icon(TablerIcons.barcode, size: 64),
            Spacer(flex: 5),
            KeyboardListener(
              autofocus: true,
              focusNode: _focusNode,
              child: SizedBox(
                child: CircularProgressIndicator(
                  color: scanning ? COLOR_ACTION : COLOR_PROGRESS
                ),
                width: 64,
                height: 64,
              ),
              onKeyEvent: (event) {
                handleKeyEvent(event);
              },
              // onBarcodeScanned: (String barcode) {
              //   debug("scanned: ${barcode}");
              //   if (scanning) {
              //     // Process the barcode data
              //     handleBarcodeData(barcode);
              //   }
              // },
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