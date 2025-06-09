import "dart:math";
import "dart:typed_data";

import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/snacks.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:one_context/one_context.dart";
import "package:wakelock_plus/wakelock_plus.dart";

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
  bool multiple_barcodes = false;

  String scanned_code = "";

  final MobileScannerController controller = MobileScannerController(
    autoZoom: true
  );

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

    controller.start();

    if (mounted) {
      setState(() {
        scanning_paused = false;
      });
    }
  }

  /*
   * Callback function when a barcode is scanned
   */
  Future<void> onScanSuccess(BarcodeCapture result) async {
    if (!mounted || scanning_paused) {
      return;
    }

    // TODO: Display outline of barcodes on the screen?

    if (result.barcodes.isEmpty) {
      setState(() {
        multiple_barcodes = false;
      });
    }
    else if (result.barcodes.length > 1) {
      setState(() {
        multiple_barcodes = true;
      });
      return;
    } else {
      setState(() {
        multiple_barcodes = false;
      });
    }

    Uint8List rawData = result.barcodes.first.rawBytes ?? Uint8List(0);

    String barcode;

    if (rawData.isNotEmpty) {
      final buffer = StringBuffer();

      for (int ii = 0; ii < rawData.length; ii++) {
        buffer.writeCharCode(rawData[ii]);
      }

      barcode = buffer.toString();

      print(barcode);
    } else {
      // Fall back to text value
      barcode = result.barcodes.first.rawValue ?? "";
    }

    if (barcode.isEmpty) {
      // TODO: Error message "empty barcode"
      return;
    }

    setState(() {
      scanned_code = barcode;
    });

    pauseScan();

    await handleBarcodeData(barcode).then((_) {
      if (!single_scanning && mounted) {
        resumeScan();
      }
    });

    resumeScan();

    if (mounted) {
      setState(() {
        scanned_code = "";
        multiple_barcodes = false;
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

  Widget BarcodeOverlay(BuildContext context) {

    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;

    final double D = min(width, height) * 0.8;

    // Color for the barcode scan?
    Color overlayColor = COLOR_ACTION;

    if (multiple_barcodes) {
      overlayColor = COLOR_DANGER;
    } else if (scanned_code.isNotEmpty) {
      overlayColor = COLOR_SUCCESS;
    } else if (scanning_paused) {
      overlayColor = COLOR_WARNING;
    }

    return Stack(
      children: [
        Center(
          child: Container(
            width: D,
            height: D,
            decoration: BoxDecoration(
              border: Border.all(
                color: overlayColor,
                width: 4,
              ),
            ),
          )
        )
      ]
    );
  }

  /*
   * Build the barcode reader widget
   */
  Widget BarcodeReader(BuildContext context) {

    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;

    final double D = min(width, height) * 0.8;

    return MobileScanner(
      controller: controller,
      overlayBuilder: (context, constraints) {
        return BarcodeOverlay(context);
      },
      scanWindow: Rect.fromCenter(
        center: Offset(width / 2, height / 2),
        width: D,
        height: D
      ),
      onDetect: (result) {
        onScanSuccess(result);
      },
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

  Widget? buildActions(BuildContext context) {

    List<SpeedDialChild> actions = [
      SpeedDialChild(
        child: Icon(flash_status ? TablerIcons.bulb_off : TablerIcons.bulb),
        label: L10().toggleTorch,
        onTap: () async {
          controller.toggleTorch();
          if (mounted) {
            setState(() {
              flash_status = !flash_status;
            });
          }
        }
      ),
      SpeedDialChild(
        child: Icon(TablerIcons.camera),
        label: L10().switchCamera,
        onTap: () async {
          controller.switchCamera();
        }
      )
    ];

    return SpeedDial(
      icon: Icons.more_horiz,
      children: actions,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: COLOR_APP_BAR,
        title: Text(L10().scanBarcode),
      ),
      floatingActionButton: buildActions(context),
      body: GestureDetector(
        onTap: () async {
          if (mounted) {
            setState(() {
              // Toggle the 'scan paused' state
              scanning_paused = !scanning_paused;
            });
          }
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
            bottomCenterOverlay()
          ],
        ),
      ),
    );
  }

}
