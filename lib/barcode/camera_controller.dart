import "dart:math";
import "dart:typed_data";

import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/snacks.dart";
import "package:one_context/one_context.dart";
import "package:wakelock_plus/wakelock_plus.dart";
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
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    super.dispose();
    WakelockPlus.disable();
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

  @override
  Future<void> pauseScan() async {
    if (mounted) {
      setState(() {
        scanning_paused = true;
      });
    }
  }

  @override
  Future<void> resumeScan() async {
    if (mounted) {
      setState(() {
        scanning_paused = false;
      });
    }
  }

  /*
   * Callback function when a barcode is scanned
   */
  Future<void> onScanSuccess(Code? code) async {

    if (scanning_paused) {
      return;
    }

    Uint8List raw_data = code?.rawBytes ?? Uint8List(0);

    // Reconstruct barcode from raw data
    String barcode;

    if (raw_data.isNotEmpty) {
      barcode = "";

      final buffer = StringBuffer();

      for (int i = 0; i < raw_data.length; i++) {
        buffer.writeCharCode(raw_data[i]);
      }

      barcode = buffer.toString();

    } else {
      barcode = code?.text ?? "";
    }

    if (mounted) {
      setState(() {
        scanned_code = barcode;
      });
    }

    if (barcode.isNotEmpty) {

      pauseScan();

      await handleBarcodeData(barcode).then((_) {
        if (!single_scanning && mounted) {
          resumeScan();
        }
      });
    }
  }

  void onControllerCreated(CameraController? controller, Exception? error) {
    if (error != null) {
      sentryReportError(
        "CameraBarcodeController.onControllerCreated",
        error,
        null
      );
    }

    if (controller == null) {
      showSnackIcon(
        L10().cameraCreationError,
        icon: TablerIcons.camera_x,
        success: false
      );

      if (OneContext.hasContext) {
        Navigator.pop(OneContext().context!);
      }
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
      onScan: onScanSuccess,
      isMultiScan: false,
      tryHarder: true,
      tryInverted: true,
      tryRotate: true,
      showGallery: false,
      onControllerCreated: onControllerCreated,
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
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: 75,
            bottom: 10
          ),
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

    String text = scanned_code.isNotEmpty ? scanned_code : info_text;

    if (text.length > 50) {
      text = text.substring(0, 50) + "...";
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: 10,
            bottom: 75
          ),
          child: Text(
              text,
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
