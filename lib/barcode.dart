import "dart:io";

import "package:inventree/inventree/sentry.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/snacks.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:one_context/one_context.dart";

import "package:qr_code_scanner/qr_code_scanner.dart";

import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";

import "package:inventree/widget/location_display.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/stock_detail.dart";


/*
 * Play an audible 'success' alert to the user.
 */
Future<void> barcodeSuccessTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    playAudioFile("sounds/barcode_scan.mp3");
  }
}

Future <void> barcodeFailureTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    playAudioFile("sounds/barcode_error.mp3");
  }
}


class BarcodeHandler {
  /*
   * Class which "handles" a barcode, by communicating with the InvenTree server,
   * and handling match / unknown / error cases.
   *
   * Override functionality of this class to perform custom actions,
   * based on the response returned from the InvenTree server
   */

  BarcodeHandler();

  String getOverlayText(BuildContext context) => "Barcode Overlay";

  QRViewController? _controller;

    Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {
      // Called when the server "matches" a barcode
      // Override this function
    }

    Future<void> onBarcodeUnknown(BuildContext context, Map<String, dynamic> data) async {
      // Called when the server does not know about a barcode
      // Override this function

      barcodeFailureTone();

      showSnackIcon(
        L10().barcodeNoMatch,
        success: false,
        icon: Icons.qr_code,
      );
    }

    Future<void> onBarcodeUnhandled(BuildContext context, Map<String, dynamic> data) async {

      barcodeFailureTone();

      // Called when the server returns an unhandled response
      showServerError("barcode/", L10().responseUnknown, data.toString());

      _controller?.resumeCamera();
    }

    Future<void> processBarcode(BuildContext context, QRViewController? _controller, String barcode, {String url = "barcode/"}) async {
      this._controller = _controller;

      print("Scanned barcode data: ${barcode}");

      if (barcode.isEmpty) {
        return;
      }

      var response = await InvenTreeAPI().post(
          url,
          body: {
            "barcode": barcode,
          },
          expectedStatusCode: null,  // Do not show an error on "unexpected code"
      );

      _controller?.resumeCamera();

      Map<String, dynamic> data = response.asMap();

      // Handle strange response from the server
      if (!response.isValid() || !response.isMap()) {
        onBarcodeUnknown(context, {});

        // We want to know about this one!
        await sentryReportMessage(
            "BarcodeHandler.processBarcode returned unexpected value",
            context: {
              "data": response.data?.toString() ?? "null",
              "barcode": barcode,
              "url": url,
              "statusCode": response.statusCode.toString(),
              "valid": response.isValid().toString(),
              "error": response.error,
              "errorDetail": response.errorDetail,
              "overlayText": getOverlayText(context),
            }
        );
      } else if ((response.statusCode >= 400) || data.containsKey("error")) {
        onBarcodeUnknown(context, data);
      } else if (data.containsKey("success")) {
        onBarcodeMatched(context, data);
      } else {
        onBarcodeUnhandled(context, data);
      }
    }
}


class BarcodeScanHandler extends BarcodeHandler {
  /*
   * Class for general barcode scanning.
   * Scan *any* barcode without context, and then redirect app to correct view
   */

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanGeneral;

  @override
  Future<void> onBarcodeUnknown(BuildContext context, Map<String, dynamic> data) async {

    barcodeFailureTone();

    showSnackIcon(
        L10().barcodeNoMatch,
        icon: FontAwesomeIcons.exclamationCircle,
        success: false,
    );
  }

  @override
  Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {

    int pk = -1;

    // A stocklocation has been passed?
    if (data.containsKey("stocklocation")) {

      pk = (data["stocklocation"]?["pk"] ?? -1) as int;

      if (pk > 0) {

        barcodeSuccessTone();

        InvenTreeStockLocation().get(pk).then((var loc) {
          if (loc is InvenTreeStockLocation) {
              Navigator.of(context).pop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
          }
        });
      } else {

        barcodeFailureTone();

        showSnackIcon(
          L10().invalidStockLocation,
          success: false
        );
      }

    } else if (data.containsKey("stockitem")) {

      pk = (data["stockitem"]?["pk"] ?? -1) as int;

      if (pk > 0) {

        barcodeSuccessTone();

        InvenTreeStockItem().get(pk).then((var item) {

            // Dispose of the barcode scanner
            Navigator.of(context).pop();

            if (item is InvenTreeStockItem) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
            }
        });
      } else {

        barcodeFailureTone();

        showSnackIcon(
            L10().invalidStockItem,
            success: false
        );
      }
    } else if (data.containsKey("part")) {

      pk = (data["part"]?["pk"] ?? -1) as int;

      if (pk > 0) {

        barcodeSuccessTone();

        InvenTreePart().get(pk).then((var part) {

            // Dismiss the barcode scanner
            Navigator.of(context).pop();

            if (part is InvenTreePart) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
            }
        });
      } else {

        barcodeFailureTone();

        showSnackIcon(
            L10().invalidPart,
            success: false
        );
      }
    } else {

      barcodeFailureTone();

      showSnackIcon(
        L10().barcodeUnknown,
        success: false,
        onAction: () {

          OneContext().showDialog(
              builder: (BuildContext context) => SimpleDialog(
                title: Text(L10().unknownResponse),
                children: <Widget>[
                  ListTile(
                    title: Text(L10().responseData),
                    subtitle: Text(data.toString()),
                  )
                ],
              )
          );
        }
      );
    }
  }
}

class StockItemScanIntoLocationHandler extends BarcodeHandler {
  /*
   * Barcode handler for scanning a provided StockItem into a scanned StockLocation
   */

  StockItemScanIntoLocationHandler(this.item);

  final InvenTreeStockItem item;

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanLocation;

  @override
  Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {
    // If the barcode points to a "stocklocation", great!
    if (data.containsKey("stocklocation")) {
      // Extract location information
      int location = (data["stocklocation"]["pk"] ?? -1) as int;

      if (location == -1) {
        showSnackIcon(
          L10().invalidStockLocation,
          success: false,
        );

        return;
      }

      // Transfer stock to specified location
      final result = await item.transferStock(context, location);

      if (result) {

        barcodeSuccessTone();

        Navigator.of(context).pop();

        showSnackIcon(
          L10().barcodeScanIntoLocationSuccess,
          success: true,
        );
      } else {

        barcodeFailureTone();

        showSnackIcon(
          L10().barcodeScanIntoLocationFailure,
          success: false
        );
      }
    } else {

      barcodeFailureTone();

      showSnackIcon(
        L10().invalidStockLocation,
        success: false,
      );
    }
  }
}


/*
 * Barcode handler for scanning stock item(s) into the specified StockLocation
 */
class StockLocationScanInItemsHandler extends BarcodeHandler {
  
  StockLocationScanInItemsHandler(this.location);

  final InvenTreeStockLocation location;

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanItem;

  @override
  Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {

    // Returned barcode must match a stock item
    if (data.containsKey("stockitem")) {

      int item_id = data["stockitem"]["pk"] as int;

      final InvenTreeStockItem? item = await InvenTreeStockItem().get(item_id) as InvenTreeStockItem?;

      if (item == null) {

        barcodeFailureTone();

        showSnackIcon(
          L10().invalidStockItem,
          success: false,
        );
      } else if (item.locationId == location.pk) {
        barcodeFailureTone();

        showSnackIcon(
            L10().itemInLocation,
            success: true
        );
      } else {
        final result = await item.transferStock(context, location.pk);

        if (result) {

          barcodeSuccessTone();

          showSnackIcon(
            L10().barcodeScanIntoLocationSuccess,
            success: true
          );
        } else {

          barcodeFailureTone();

          showSnackIcon(
            L10().barcodeScanIntoLocationFailure,
            success: false
          );
        }
      }
    } else {

      barcodeFailureTone();

      // Does not match a valid stock item!
      showSnackIcon(
        L10().invalidStockItem,
        success: false,
      );
    }
  }
}


class UniqueBarcodeHandler extends BarcodeHandler {
  /*
   * Barcode handler for finding a "unique" barcode (one that does not match an item in the database)
   */

  UniqueBarcodeHandler(this.callback, {this.overlayText = ""});

  // Callback function when a "unique" barcode hash is found
  final Function(String) callback;

  final String overlayText;

  @override
  String getOverlayText(BuildContext context) {
    if (overlayText.isEmpty) {
      return L10().barcodeScanAssign;
    } else {
      return overlayText;
    }
  }

  @override
  Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {

    barcodeFailureTone();

    // If the barcode is known, we can"t assign it to the stock item!
    showSnackIcon(
        L10().barcodeInUse,
        icon: Icons.qr_code,
        success: false
    );
  }

  @override
  Future<void> onBarcodeUnknown(BuildContext context, Map<String, dynamic> data) async {
    // If the barcode is unknown, we *can* assign it to the stock item!

    if (!data.containsKey("hash")) {
      showServerError(
        "barcode/",
        L10().missingData,
        L10().barcodeMissingHash,
      );
    } else {
      String hash = (data["hash"] ?? "") as String;

      if (hash.isEmpty) {
        barcodeFailureTone();

        showSnackIcon(
          L10().barcodeError,
          success: false,
        );
      } else {

        barcodeSuccessTone();

        // Close the barcode scanner
        Navigator.of(context).pop();

        callback(hash);
      }
    }
  }
}


class InvenTreeQRView extends StatefulWidget {

  const InvenTreeQRView(this._handler, {Key? key}) : super(key: key);

  final BarcodeHandler _handler;

  @override
  State<StatefulWidget> createState() => _QRViewState(_handler);
}


class _QRViewState extends State<InvenTreeQRView> {

  _QRViewState(this._handler) : super();

  final GlobalKey qrKey = GlobalKey(debugLabel: "QR");

  QRViewController? _controller;

  final BarcodeHandler _handler;

  bool flash_status = false;

  Future<void> updateFlashStatus() async {
    final bool? status = await _controller?.getFlashStatus();

    flash_status = status != null && status;

    // Reload
    setState(() {

    });
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();

    if (Platform.isAndroid) {
      _controller!.pauseCamera();
    }

    _controller!.resumeCamera();
  }

  void _onViewCreated(BuildContext context, QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((barcode) {
      _controller?.pauseCamera();

      if (barcode.code != null) {
        _handler.processBarcode(context, _controller, barcode.code ?? "");
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

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
                    key: qrKey,
                    onQRViewCreated: (QRViewController controller) {
                      _onViewCreated(context, controller);
                    },
                    overlay: QrScannerOverlayShape(
                      borderColor: Colors.red,
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
                      Padding(
                        child: Text(_handler.getOverlayText(context),
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

Future<void> scanQrCode(BuildContext context) async {

  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeQRView(BarcodeScanHandler())));

  return;
}