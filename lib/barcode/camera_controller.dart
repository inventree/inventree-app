import "dart:io";
import "dart:math";
import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/preferences.dart";

import "package:flutter_zxing/flutter_zxing.dart";

import "package:inventree/l10.dart";

import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/controller.dart";

/*
 * Barcode controller which uses the device's camera to scan barcodes.
 * Under the hood it uses the qr_code_scanner package.
 */
class CameraBarcodeController extends InvenTreeBarcodeController {
  const CameraBarcodeController(BarcodeHandler handler, {Key? key})
      : super(handler, key: key);

  @override
  State<StatefulWidget> createState() => _CameraBarcodeControllerState();
}

class _CameraBarcodeControllerState extends InvenTreeBarcodeControllerState {
  _CameraBarcodeControllerState() : super();

  bool flash_status = false;

  int scan_delay = 500;
  bool single_scanning = false;
  bool scanning_paused = false;

  String scanned_code = "";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /*
   * Load the barcode scanning settings
   */
  Future<void> _loadSettings() async {
    bool _single = await InvenTreeSettingsManager()
        .getBool(INV_BARCODE_SCAN_SINGLE, false);

    int _delay = await InvenTreeSettingsManager()
        .getValue(INV_BARCODE_SCAN_DELAY, 500) as int;

    if (mounted) {
      setState(() {
        scan_delay = _delay;
        single_scanning = _single;
        scanning_paused = false;
      });
    }
  }

  /*
   * Callback function when a barcode is scanned
   */
  void _onScanSuccess(Code? code) {

    if (scanning_paused) {
      return;
    }

    String barcode_data = code?.text ?? "";

    if (mounted) {
      setState(() {
        scanned_code = barcode_data;
        scanning_paused = barcode_data.isNotEmpty;
      });
    }

    if (barcode_data.isNotEmpty) {
      handleBarcodeData(barcode_data).then((_) {
        if (!single_scanning && mounted) {
          // Resume next scan
          setState(() {
            scanning_paused = false;
          });
        }
      });
    }

  }

  /*
   * Build the barcode scanner overlay
   */
  FixedScannerOverlay BarcodeOverlay(BuildContext context) {

    // Note: Copied from reader_widget.dart:ReaderWidget.build
    final Size size = MediaQuery.of(context).size;
    final double cropSize = min(size.width, size.height) * 0.5;

    return FixedScannerOverlay(
      borderColor: scanning_paused ? COLOR_WARNING : COLOR_ACTION,
      overlayColor: Colors.black45,
      borderRadius: 1,
      borderLength: 15,
      borderWidth: 8,
      cutOutSize: cropSize,
    );
  }

  /*
   * Build the barcode reader widget
   */
  Widget BarcodeReader(BuildContext context) {

    return ReaderWidget(
      onScan: _onScanSuccess,
      isMultiScan: false,
      tryHarder: true,
      tryInverted: true,
      tryRotate: true,
      showGallery: false,
      scanDelay: Duration(milliseconds: scan_delay),
      resolution: ResolutionPreset.high,
      lensDirection: CameraLensDirection.back,
      flashOnIcon: const Icon(Icons.flash_on),
      flashOffIcon: const Icon(Icons.flash_off),
      toggleCameraIcon: const Icon(TablerIcons.camera_rotate),
      actionButtonsBackgroundBorderRadius:
      BorderRadius.circular(40),
      scannerOverlay: BarcodeOverlay(context),
      actionButtonsBackgroundColor: Colors.black.withOpacity(0.7),
    );
  }

  Widget topCenterOverlay() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            widget.handler.getOverlayText(context),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold
            )
          )
        )
      )
    );
  }

  Widget bottomCenterOverlay() {

    String info_text = scanning_paused ? L10().barcodeScanPaused : L10().barcodeScanPause;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Text(
              scanned_code.isNotEmpty ? scanned_code : info_text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold
              )
          ),
        )
      )
    );
  }


  /*
   *  Display an overlay at the bottom right of the screen
   */
  Widget bottomRightOverlay() {
    return SafeArea(
        child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
                padding: EdgeInsets.all(10),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: ColoredBox(
                        color: Colors.black45,
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: scanning_paused ? [] : [
                              CircularProgressIndicator(
                                  value: null
                              )
                              // actionIcon,
                            ]
                        )
                    )
                )
            )
        )
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: COLOR_APP_BAR,
        title: Text(L10().scanBarcode),
      ),
      body: GestureDetector(
        onTap: () async {
          setState(() {
            scanning_paused = !scanning_paused;
          });
        },
        child: Stack(
          children: <Widget>[
            Column(
              children: [
                Expanded(
                    child: BarcodeReader(context)
                ),
              ],
            ),
            topCenterOverlay(),
            bottomCenterOverlay(),
            bottomRightOverlay(),
          ],
        ),
      ),
    );
  }

}
