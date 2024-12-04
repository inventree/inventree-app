import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";

import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/controller.dart";

class ScannerErrorWidget extends StatelessWidget {
  const ScannerErrorWidget({super.key, required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    String errorMessage;

    switch (error.errorCode) {
      case MobileScannerErrorCode.controllerUninitialized:
        // TODO: Translated message
        errorMessage = 'Controller not ready.';
        break;
      case MobileScannerErrorCode.permissionDenied:
        // TODO: Translated message
        errorMessage = 'Permission denied';
        break;
      case MobileScannerErrorCode.unsupported:
        // TODO: Translated message
        errorMessage = 'Scanning is unsupported on this device';
        break;
      default:
        // TODO: Translated message
        errorMessage = 'Generic Error';
        break;
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Icon(Icons.error, color: Colors.white),
            ),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              error.errorDetails?.message ?? '',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}


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

class _CameraBarcodeControllerState extends InvenTreeBarcodeControllerState with WidgetsBindingObserver {
  _CameraBarcodeControllerState() : super();

  final MobileScannerController controller = MobileScannerController();
  StreamSubscription<Object?>? _subscription;

  bool flash_status = false;
  bool single_scanning = false;
  bool scanning_paused = false;


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the controller is not ready, do not try to start or stop it.
    // Permission dialogs can trigger lifecycle changes before the controller is ready.
    if (!controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
        return;
      case AppLifecycleState.hidden:
        return;
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
      // Restart the scanner when the app is resumed.
      // Don't forget to resume listening to the barcode events.
        _subscription = controller.barcodes.listen(_handleBarcode);

        unawaited(controller.start());
        break;
      case AppLifecycleState.inactive:
      // Stop the scanner when the app is paused.
      // Also stop the barcode events subscription.
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
        break;
    }
  }

  Future<void> _loadSettings() async {
    bool _single = await InvenTreeSettingsManager()
        .getBool(INV_BARCODE_SCAN_SINGLE, false);

    if (mounted) {
      setState(() {
        single_scanning = _single;
        scanning_paused = false;
      });
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    // TODO: Pass barcode data back to handler
    print("barcode: ${barcodes.barcodes.firstOrNull}");
  }

  @override
  void initState() {
    super.initState();
    // Start listening to lifecycle changes.
    WidgetsBinding.instance.addObserver(this);

    // Start listening to the barcode events.
    _subscription = controller.barcodes.listen(_handleBarcode);

    // Finally, start the scanner itself.
    unawaited(controller.start());
  }

  @override
  Future<void> dispose() async {
    // Stop listening to lifecycle changes.
    WidgetsBinding.instance.removeObserver(this);
    // Stop listening to the barcode events.
    unawaited(_subscription?.cancel());
    _subscription = null;
    // Dispose the widget itself.
    super.dispose();
    // Finally, dispose of the controller.
    await controller.dispose();
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();

    if (mounted) {
      if (Platform.isAndroid) {
        controller.stop();
      }

      controller.start();
    }
  }



  @override
  Future<void> pauseScan() async {

    try {
      await controller.stop();
    } on Exception {
      // do nothing
    }
  }

  @override
  Future<void> resumeScan() async {
    // Do not attempt to resume if the widget is not mounted
    if (!mounted) {
      return;
    }

    try {
      await controller.start();
    } on Exception {
      // do nothing
    }
  }

  // Toggle the status of the camera flash
  Future<void> updateFlashStatus() async {

    if (mounted) {
      setState(() {
        flash_status = controller.torchEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget actionIcon =
        Icon(TablerIcons.player_pause, color: COLOR_WARNING, size: 64);

    if (scanning_paused) {
      actionIcon =
          Icon(TablerIcons.player_play, color: COLOR_ACTION, size: 64);
    }

    String info_text = scanning_paused ? L10().barcodeScanPaused : L10().barcodeScanPause;

    return Scaffold(
        appBar: AppBar(
          title: Text(L10().scanBarcode),
          actions: [
            IconButton(
                icon: Icon(Icons.flip_camera_android),
                onPressed: () {
                  // TODO: Flip camera
                }),
            IconButton(
              icon: flash_status ? Icon(Icons.flash_off) : Icon(Icons.flash_on),
              onPressed: () {
                // TODO: Toggle flash
                updateFlashStatus();
              },
            )
          ],
        ),
        body: GestureDetector(
            onTapDown: (details) async {
              setState(() {
                scanning_paused = !scanning_paused;
              });
            },
            onLongPressEnd: (details) async {
              if (mounted) {
                setState(() {
                  scanning_paused = false;
                });
              }
            },
            child: Stack(
              children: <Widget>[
                Column(children: [
                  Expanded(
                    child: MobileScanner(
                      controller: controller,
                      errorBuilder: (context, error, child) {
                        return ScannerErrorWidget(error: error);
                      },
                      fit: BoxFit.contain,
                      ),
                    ),
                    // overlay: QrScannerOverlayShape(
                    //   borderColor:
                    //       scanning_paused ? COLOR_WARNING : COLOR_ACTION,
                    //   borderRadius: 10,
                    //   borderLength: 30,
                    //   borderWidth: 10,
                    //   cutOutSize: 300,
                    // ),
                ]),
                Center(
                    child: Column(children: [
                  Padding(
                      child: Text(
                        widget.handler.getOverlayText(context),
                        style: TextStyle(
                          fontSize: 16,
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      padding: EdgeInsets.all(25)),
                  Padding(
                    child: CircularProgressIndicator(
                        value: scanning_paused ? 0 : null),
                    padding: EdgeInsets.all(40),
                  ),
                  Spacer(),
                  SizedBox(
                    child: Center(
                      child: actionIcon,
                    ),
                    width: 100,
                    height: 150,
                  ),
                  Padding(
                    child: Text(info_text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                        )),
                    padding: EdgeInsets.all(25),
                  ),
                ]))
              ],
            )));
  }
}
