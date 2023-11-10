import "dart:io";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/app_colors.dart";

import "package:qr_code_scanner/qr_code_scanner.dart";

import "package:inventree/l10.dart";

import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/controller.dart";

/*
 * Barcode controller which uses the device's camera to scan barcodes.
 * Under the hood it uses the qr_code_scanner package.
 */
class CameraBarcodeController extends InvenTreeBarcodeController {

  const CameraBarcodeController(BarcodeHandler handler, {Key? key}) : super(handler, key: key);

  @override
  State<StatefulWidget> createState() => _CameraBarcodeControllerState();

}


class _CameraBarcodeControllerState extends InvenTreeBarcodeControllerState {

  _CameraBarcodeControllerState() : super();

  QRViewController? _controller;

  bool flash_status = false;

  bool scanning_paused = false;

  /* Callback function when the Barcode scanner view is initially created */
  void _onViewCreated(BuildContext context, QRViewController controller) {
    _controller = controller;

    controller.scannedDataStream.listen((barcode) {

      if (!scanning_paused) {
        handleBarcodeData(barcode.code);
      }
    });
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();

    if (mounted) {
      if (Platform.isAndroid) {
        _controller!.pauseCamera();
      }

      _controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Future<void> pauseScan() async {
    try {
      await _controller?.pauseCamera();
    } on CameraException {
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
      await _controller?.resumeCamera();
    } on CameraException {
      // do nothing
    }
  }

  // Toggle the status of the camera flash
  Future<void> updateFlashStatus() async {
    final bool? status = await _controller?.getFlashStatus();

    if (mounted) {
      setState(() {
        flash_status = status != null && status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    Widget actionIcon = FaIcon(FontAwesomeIcons.pause, color: COLOR_WARNING, size: 48);

    if (scanning_paused) {
      actionIcon = FaIcon(FontAwesomeIcons.play, color: COLOR_ACTION, size: 48);
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(L10().scanBarcode),
          actions: [
            IconButton(
              icon: Icon(Icons.flip_camera_android),
              onPressed: () {
                _controller?.flipCamera();
              }
            ),
            IconButton(
              icon: flash_status ? Icon(Icons.flash_off) : Icon(Icons.flash_on),
              onPressed: () {
                _controller?.toggleFlash();
                updateFlashStatus();
              },
            )
          ],
        ),
        body: Stack(
          children: <Widget>[
            Column(
              children: [
                Expanded(
                  child: QRView(
                    key: barcodeControllerKey,
                    onQRViewCreated: (QRViewController controller) {
                      _onViewCreated(context, controller);
                    },
                    overlay: QrScannerOverlayShape(
                      borderColor: scanning_paused ? COLOR_WARNING : COLOR_ACTION,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 300,
                    ),
                  )
                )
              ]
            ),
            Center(
                child: Column(
                    children: [
                      Spacer(),
                      SizedBox(
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              scanning_paused = !scanning_paused;
                            });
                          },
                          icon: actionIcon,
                        ),
                        width: 64,
                        height: 64,
                      ),
                      Padding(
                        child: Text(widget.handler.getOverlayText(context),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        padding: EdgeInsets.all(20),
                      ),
                    ]
                )
            )
          ],
        )
    );
  }
}
