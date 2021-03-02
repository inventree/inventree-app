import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:one_context/one_context.dart';

import 'package:device_info/device_info.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/stock_detail.dart';

import 'dart:io';
import 'dart:convert';


class BarcodeHandler {
  /**
   * Class which "handles" a barcode, by communicating with the InvenTree server,
   * and handling match / unknown / error cases.
   *
   * Override functionality of this class to perform custom actions,
   * based on the response returned from the InvenTree server
   */

    String getOverlayText(BuildContext context) => "Barcode Overlay";

    BarcodeHandler();

    QRViewController _controller;
    BuildContext _context;

    void successTone() {
      AudioCache player = AudioCache();
      player.play("sounds/barcode_scan.mp3");
    }

    void failureTone() {
      AudioCache player = AudioCache();
      player.play("sounds/barcode_error.mp3");
    }

    Future<void> onBarcodeMatched(Map<String, dynamic> data) {
      // Called when the server "matches" a barcode
      // Override this function
    }

    Future<void> onBarcodeUnknown(Map<String, dynamic> data) {
      // Called when the server does not know about a barcode
      // Override this function

      failureTone();

      showSnackIcon(
        I18N.of(OneContext().context).barcodeNoMatch,
        success: false,
        icon: FontAwesomeIcons.qrcode
      );
    }

    Future<void> onBarcodeUnhandled(Map<String, dynamic> data) {

      failureTone();

      // Called when the server returns an unhandled response
      showServerError(I18N.of(OneContext().context).responseUnknown, data.toString());

      _controller.resumeCamera();
    }

    Future<void> processBarcode(BuildContext context, QRViewController _controller, String barcode, {String url = "barcode/"}) {
      this._context = context;
      this._controller = _controller;

      print("Scanned barcode data: ${barcode}");

      // Send barcode request to server
      InvenTreeAPI().post(
          url,
          body: {
            "barcode": barcode
          }
      ).then((var response) {

        if (response.statusCode != 200) {
          showStatusCodeError(response.statusCode);
          _controller.resumeCamera();

          return;
        }

        // Decode the response
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('error')) {
          _controller.resumeCamera();
          onBarcodeUnknown(data);
        } else if (data.containsKey('success')) {
          _controller.resumeCamera();
          onBarcodeMatched(data);
        } else {
          _controller.resumeCamera();
          onBarcodeUnhandled(data);
        }
      }).timeout(
          Duration(seconds: 5)
      ).catchError((error) {

        showServerError(I18N.of(OneContext().context).error, error.toString());
        _controller.resumeCamera();

        return;
      });
    }
}


class BarcodeScanHandler extends BarcodeHandler {
  /**
   * Class for general barcode scanning.
   * Scan *any* barcode without context, and then redirect app to correct view
   */

  @override
  String getOverlayText(BuildContext context) => I18N.of(context).barcodeScanGeneral;

  @override
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) {

    failureTone();

    showSnackIcon(
        I18N.of(OneContext().context).barcodeNoMatch,
        icon: FontAwesomeIcons.exclamationCircle,
        success: false,
    );
  }

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) {
    int pk;

    print("Handle barcode:");
    print(data);

    // A stocklocation has been passed?
    if (data.containsKey('stocklocation')) {

      pk = data['stocklocation']['pk'] as int ?? null;

      if (pk != null) {

        successTone();

        InvenTreeStockLocation().get(_context, pk).then((var loc) {
          if (loc is InvenTreeStockLocation) {
            Navigator.of(_context).pop();
            Navigator.push(_context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
          }
        });
      } else {

        failureTone();

        showSnackIcon(
          I18N.of(OneContext().context).invalidStockLocation,
          success: false
        );
      }

    } else if (data.containsKey('stockitem')) {

      pk = data['stockitem']['pk'] as int ?? null;

      if (pk != null) {

        successTone();

        InvenTreeStockItem().get(_context, pk).then((var item) {
          Navigator.of(_context).pop();
          Navigator.push(_context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
        });
      } else {

        failureTone();

        showSnackIcon(
            I18N.of(OneContext().context).invalidStockItem,
            success: false
        );
      }
    } else if (data.containsKey('part')) {

      pk = data['part']['pk'] as int ?? null;

      if (pk != null) {

        successTone();

        InvenTreePart().get(_context, pk).then((var part) {
          Navigator.of(_context).pop();
          Navigator.push(_context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
        });
      } else {

        failureTone();

        showSnackIcon(
            I18N.of(OneContext().context).invalidPart,
            success: false
        );
      }
    } else {

      failureTone();

      showSnackIcon(
        I18N.of(OneContext().context).barcodeUnknown,
        success: false,
        onAction: () {
          showDialog(
              context: _context,
              child: SimpleDialog(
                title: Text(I18N.of(_context).unknownResponse),
                children: <Widget>[
                  ListTile(
                    title: Text("Response data"),
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
  /**
   * Barcode handler for assigning a new barcode to a stock item
   */

  final InvenTreeStockItem item;

  StockItemBarcodeAssignmentHandler(this.item);

  @override
  String getOverlayText(BuildContext context) => I18N.of(context).barcodeScanAssign;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) {

    failureTone();

    // If the barcode is known, we can't assign it to the stock item!
    showSnackIcon(
      I18N.of(OneContext().context).barcodeInUse,
      icon: FontAwesomeIcons.qrcode,
      success: false
    );
  }

  @override
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) {
    // If the barcode is unknown, we *can* assign it to the stock item!

    if (!data.containsKey("hash")) {
      showServerError("Missing data", "Barcode hash data missing from response");
    } else {

      // Send the 'hash' code as the UID for the stock item
      item.update(
        _context,
        values: {
          "uid": data['hash'],
        }
      ).then((result) {
        if (result) {

          failureTone();

          // Close the barcode scanner
          _controller.dispose();
          Navigator.of(_context).pop();

          showSnackIcon(
            I18N.of(OneContext().context).barcodeAssigned,
            success: true,
            icon: FontAwesomeIcons.qrcode
          );
        } else {

          successTone();

          showSnackIcon(
              I18N.of(OneContext().context).barcodeNotAssigned,
              success: false,
              icon: FontAwesomeIcons.qrcode
          );
        }
      });
    }
  }
}





class StockItemScanIntoLocationHandler extends BarcodeHandler {
  /**
   * Barcode handler for scanning a provided StockItem into a scanned StockLocation
   */

  final InvenTreeStockItem item;

  StockItemScanIntoLocationHandler(this.item);

  @override
  String getOverlayText(BuildContext context) => I18N.of(context).barcodeScanLocation;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    // If the barcode points to a 'stocklocation', great!
    if (data.containsKey('stocklocation')) {
      // Extract location information
      int location = data['stocklocation']['pk'] as int;

      // Transfer stock to specified location
      final result = await item.transferStock(location);

      if (result) {

        successTone();

        // Close the scanner
        _controller.dispose();
        Navigator.of(_context).pop();

        showSnackIcon(
          I18N.of(OneContext().context).barcodeScanIntoLocationSuccess,
          success: true,
        );
      } else {

        failureTone();

        showSnackIcon(
          I18N.of(OneContext().context).barcodeScanIntoLocationFailure,
          success: false
        );
      }
    } else {

      failureTone();

      showSnackIcon(
        I18N.of(OneContext().context).invalidStockLocation,
        success: false,
      );
    }
  }
}


class StockLocationScanInItemsHandler extends BarcodeHandler {
  /**
   * Barcode handler for scanning stock item(s) into the specified StockLocation
   */
  
  final InvenTreeStockLocation location;
  
  StockLocationScanInItemsHandler(this.location);
  
  @override
  String getOverlayText(BuildContext context) => I18N.of(context).barcodeScanItem;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {

    // Returned barcode must match a stock item
    if (data.containsKey('stockitem')) {

      int item_id = data['stockitem']['pk'] as int;

      final InvenTreeStockItem item = await InvenTreeStockItem().get(_context, item_id);

      if (item == null) {

        failureTone();

        showSnackIcon(
          I18N.of(OneContext().context).invalidStockItem,
          success: false,
        );
      } else if (item.locationId == location.pk) {
        failureTone();

        showSnackIcon(
            I18N
                .of(OneContext().context)
                .itemInLocation,
            success: true
        );
      } else {
        final result = await item.transferStock(location.pk);

        if (result) {

          successTone();

          showSnackIcon(
            I18N.of(OneContext().context).barcodeScanIntoLocationSuccess,
            success: true
          );
        } else {

          failureTone();

          showSnackIcon(
            I18N.of(OneContext().context).barcodeScanIntoLocationFailure,
            success: false
          );
        }
      }
    } else {

      failureTone();

      // Does not match a valid stock item!
      showSnackIcon(
        I18N.of(OneContext().context).invalidStockItem,
        success: false,
      );
    }
  }
}


class InvenTreeQRView extends StatefulWidget {

  final BarcodeHandler _handler;

  InvenTreeQRView(this._handler, {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewState(_handler);
}


class _QRViewState extends State<InvenTreeQRView> {

  QRViewController _controller;

  final BarcodeHandler _handler;

  BuildContext context;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller.pauseCamera();
    } else if (Platform.isIOS) {
      _controller.resumeCamera();
    }
  }

  _QRViewState(this._handler) : super();

  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  void _onViewCreated(QRViewController controller) {
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

    // Save the context for later on!
    this.context = context;

    return Scaffold(
        body: Stack(
          children: <Widget>[
            Column(
              children: [
                Expanded(
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: _onViewCreated,
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