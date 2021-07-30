import 'package:inventree/app_settings.dart';
import 'package:inventree/widget/dialogs.dart';
import 'package:inventree/widget/snacks.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:one_context/one_context.dart';

import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:inventree/inventree/stock.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/l10.dart';

import 'package:inventree/api.dart';

import 'package:inventree/widget/location_display.dart';
import 'package:inventree/widget/part_detail.dart';
import 'package:inventree/widget/stock_detail.dart';

import 'dart:io';


class BarcodeHandler {
  /*
   * Class which "handles" a barcode, by communicating with the InvenTree server,
   * and handling match / unknown / error cases.
   *
   * Override functionality of this class to perform custom actions,
   * based on the response returned from the InvenTree server
   */

    String getOverlayText(BuildContext context) => "Barcode Overlay";

    BarcodeHandler();

    QRViewController? _controller;

    void successTone() async {

      final bool en = await InvenTreeSettingsManager().getValue("barcodeSounds", true) as bool;

      if (en) {
        final player = AudioCache();
        player.play("sounds/barcode_scan.mp3");
      }
    }

    void failureTone() async {

      final bool en = await InvenTreeSettingsManager().getValue("barcodeSounds", true) as bool;

      if (en) {
        final player = AudioCache();
        player.play("sounds/barcode_error.mp3");
      }
    }

    Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {
      // Called when the server "matches" a barcode
      // Override this function
    }

    Future<void> onBarcodeUnknown(BuildContext context, Map<String, dynamic> data) async {
      // Called when the server does not know about a barcode
      // Override this function

      failureTone();

      showSnackIcon(
        L10().barcodeNoMatch,
        success: false,
        icon: FontAwesomeIcons.qrcode
      );
    }

    Future<void> onBarcodeUnhandled(BuildContext context, Map<String, dynamic> data) async {

      failureTone();

      // Called when the server returns an unhandled response
      showServerError(L10().responseUnknown, data.toString());

      _controller?.resumeCamera();
    }

    Future<void> processBarcode(BuildContext context, QRViewController? _controller, String barcode, {String url = "barcode/"}) async {
      this._controller = _controller;

      print("Scanned barcode data: ${barcode}");

      var response = await InvenTreeAPI().post(
          url,
          body: {
            "barcode": barcode,
          },
          expectedStatusCode: 200
      );

      if (!response.isValid()) {
        return;
      }

      if (response.data.containsKey('error')) {
        _controller?.resumeCamera();
        onBarcodeUnknown(context, response.data);
      } else if (response.data.containsKey('success')) {
        _controller?.resumeCamera();
        onBarcodeMatched(context, response.data);
      } else {
        _controller?.resumeCamera();
        onBarcodeUnhandled(context, response.data);
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

    failureTone();

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
    if (data.containsKey('stocklocation')) {

      pk = (data['stocklocation']?['pk'] ?? -1) as int;

      if (pk > 0) {

        successTone();

        InvenTreeStockLocation().get(pk).then((var loc) {
          if (loc is InvenTreeStockLocation) {
              Navigator.of(context).pop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
          }
        });
      } else {

        failureTone();

        showSnackIcon(
          L10().invalidStockLocation,
          success: false
        );
      }

    } else if (data.containsKey('stockitem')) {

      pk = (data['stockitem']?['pk'] ?? -1) as int;

      if (pk > 0) {

        successTone();

        InvenTreeStockItem().get(pk).then((var item) {

            // Dispose of the barcode scanner
            Navigator.of(context).pop();

            if (item is InvenTreeStockItem) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
            }
        });
      } else {

        failureTone();

        showSnackIcon(
            L10().invalidStockItem,
            success: false
        );
      }
    } else if (data.containsKey('part')) {

      pk = (data['part']?['pk'] ?? -1) as int;

      if (pk > 0) {

        successTone();

        InvenTreePart().get(pk).then((var part) {

            // Dismiss the barcode scanner
            Navigator.of(context).pop();

            if (part is InvenTreePart) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
            }
        });
      } else {

        failureTone();

        showSnackIcon(
            L10().invalidPart,
            success: false
        );
      }
    } else {

      failureTone();

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


class StockItemBarcodeAssignmentHandler extends BarcodeHandler {
  /*
   * Barcode handler for assigning a new barcode to a stock item
   */

  final InvenTreeStockItem item;

  StockItemBarcodeAssignmentHandler(this.item);

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanAssign;

  @override
  Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {

    failureTone();

    // If the barcode is known, we can't assign it to the stock item!
    showSnackIcon(
      L10().barcodeInUse,
      icon: FontAwesomeIcons.qrcode,
      success: false
    );
  }

  @override
  Future<void> onBarcodeUnknown(BuildContext context, Map<String, dynamic> data) async {
    // If the barcode is unknown, we *can* assign it to the stock item!

    if (!data.containsKey("hash")) {
      showServerError(
          L10().missingData,
          L10().barcodeMissingHash,
      );
    } else {

      // Send the 'hash' code as the UID for the stock item
      item.update(
        values: {
          "uid": data['hash'],
        }
      ).then((result) {
        if (result) {

          failureTone();

          Navigator.of(context).pop();

          showSnackIcon(
            L10().barcodeAssigned,
            success: true,
            icon: FontAwesomeIcons.qrcode
          );
        } else {

          successTone();

          showSnackIcon(
              L10().barcodeNotAssigned,
              success: false,
              icon: FontAwesomeIcons.qrcode
          );
        }
      });
    }
  }
}

class StockItemScanIntoLocationHandler extends BarcodeHandler {
  /*
   * Barcode handler for scanning a provided StockItem into a scanned StockLocation
   */

  final InvenTreeStockItem item;

  StockItemScanIntoLocationHandler(this.item);

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanLocation;

  @override
  Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {
    // If the barcode points to a 'stocklocation', great!
    if (data.containsKey('stocklocation')) {
      // Extract location information
      int location = (data['stocklocation']['pk'] ?? -1) as int;

      if (location == -1) {
        showSnackIcon(
          L10().invalidStockLocation,
          success: false,
        );

        return;
      }

      // Transfer stock to specified location
      final result = await item.transferStock(location);

      if (result) {

        successTone();

        Navigator.of(context).pop();

        showSnackIcon(
          L10().barcodeScanIntoLocationSuccess,
          success: true,
        );
      } else {

        failureTone();

        showSnackIcon(
          L10().barcodeScanIntoLocationFailure,
          success: false
        );
      }
    } else {

      failureTone();

      showSnackIcon(
        L10().invalidStockLocation,
        success: false,
      );
    }
  }
}


class StockLocationScanInItemsHandler extends BarcodeHandler {
  /*
   * Barcode handler for scanning stock item(s) into the specified StockLocation
   */
  
  final InvenTreeStockLocation location;
  
  StockLocationScanInItemsHandler(this.location);
  
  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanItem;

  @override
  Future<void> onBarcodeMatched(BuildContext context, Map<String, dynamic> data) async {

    // Returned barcode must match a stock item
    if (data.containsKey('stockitem')) {

      int item_id = data['stockitem']['pk'] as int;

      final InvenTreeStockItem? item = await InvenTreeStockItem().get(item_id) as InvenTreeStockItem;

      if (item == null) {

        failureTone();

        showSnackIcon(
          L10().invalidStockItem,
          success: false,
        );
      } else if (item.locationId == location.pk) {
        failureTone();

        showSnackIcon(
            L10().itemInLocation,
            success: true
        );
      } else {
        final result = await item.transferStock(location.pk);

        if (result) {

          successTone();

          showSnackIcon(
            L10().barcodeScanIntoLocationSuccess,
            success: true
          );
        } else {

          failureTone();

          showSnackIcon(
            L10().barcodeScanIntoLocationFailure,
            success: false
          );
        }
      }
    } else {

      failureTone();

      // Does not match a valid stock item!
      showSnackIcon(
        L10().invalidStockItem,
        success: false,
      );
    }
  }
}


class InvenTreeQRView extends StatefulWidget {

  final BarcodeHandler _handler;

  InvenTreeQRView(this._handler, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewState(_handler);
}


class _QRViewState extends State<InvenTreeQRView> {

  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  QRViewController? _controller;

  final BarcodeHandler _handler;

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

  _QRViewState(this._handler) : super();

  void _onViewCreated(BuildContext context, QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((barcode) {
      _controller?.pauseCamera();
      _handler.processBarcode(context, _controller, barcode.code);
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