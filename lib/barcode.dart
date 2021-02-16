import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:one_context/one_context.dart';

import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/stock_detail.dart';

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

    Future<void> onBarcodeMatched(Map<String, dynamic> data) {
      // Called when the server "matches" a barcode
      // Override this function
    }

    Future<void> onBarcodeUnknown(Map<String, dynamic> data) {
      // Called when the server does not know about a barcode
      // Override this function
      showErrorDialog(
        _context,
        "Invalid Barcode",
        "Barcode does not match any known item",
        error: "Barcode Error",
        icon: FontAwesomeIcons.barcode,
        onDismissed: () {
          _controller.resumeCamera();
        }
      );
    }

    Future<void> onBarcodeUnhandled(Map<String, dynamic> data) {
      // Called when the server returns an unhandled response
      showErrorDialog(
          _context,
          "Response Data",
          data.toString(),
          error: "Unknown Response",
          onDismissed: () {
            _controller.resumeCamera();
          }
      );
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
          showErrorDialog(
            context,
            "Status Code: ${response.statusCode}",
            "${response.body
                .toString()
                .split('\n')
                .first}",
            onDismissed: () {
              _controller.resumeCamera();
            },
            error: "Server Error",
            icon: FontAwesomeIcons.server,
          );

          return;
        }

        // Decode the response
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('error')) {
          onBarcodeUnknown(data);
        } else if (data.containsKey('success')) {
          onBarcodeMatched(data);
        } else {
          onBarcodeUnhandled(data);
        }
      }).timeout(
          Duration(seconds: 5)
      ).catchError((error) {

        showErrorDialog(
            context,
            "Error",
            error.toString(),
            onDismissed: () {
              _controller.resumeCamera();
            }
        );
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

    showSnackIcon(
        "No barcode",
        icon: FontAwesomeIcons.exclamationCircle,
        onTap: () {
          print("Tappity");
        },
        success: true,
    );

    _controller.resumeCamera();

    /*
    showErrorDialog(
        _context,
        data['error'] ?? '',
        data['plugin'] ?? 'No barcode plugin information',
        error: "Barcode Error",
        icon: FontAwesomeIcons.barcode,
        onDismissed: () {
          _controller.resumeCamera();
        }
    );

     */
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
        InvenTreeStockLocation().get(_context, pk).then((var loc) {
          if (loc is InvenTreeStockLocation) {
            Navigator.of(_context).pop();
            Navigator.push(_context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
          }
        });
      } else {
        // TODO - Show an error here!
      }

    } else if (data.containsKey('stockitem')) {

      pk = data['stockitem']['pk'] as int ?? null;

      if (pk != null) {
        InvenTreeStockItem().get(_context, pk).then((var item) {
          Navigator.of(_context).pop();
          Navigator.push(_context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
        });
      } else {
        // TODO - Show an error here!
      }
    } else if (data.containsKey('part')) {

      pk = data['part']['pk'] as int ?? null;

      if (pk != null) {
        InvenTreePart().get(_context, pk).then((var part) {
          Navigator.of(_context).pop();
          Navigator.push(_context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
        });
      } else {
        // TODO - Show an error here!
      }
    } else {
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
    // If the barcode is known, we can't asisgn it to the stock item!
    showErrorDialog(
      _context,
      "Barcode in Use",
      "Barcode is already known",
      onDismissed: () {
        _controller.resumeCamera();
      }
    );
  }

  @override
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) {
    // If the barcode is unknown, we *can* assign it to the stock item!

    if (!data.containsKey("hash")) {
      showErrorDialog(
        _context,
        "Missing Data",
        "Missing hash data from server",
        onDismissed: () {
          _controller.resumeCamera();
        }
      );
    } else {
      // Send the 'hash' code as the UID for the stock item
      item.update(
        _context,
        values: {
          "uid": data['hash'],
        }
      ).then((result) {
        if (result) {
          showInfoDialog(
              _context,
              "Barcode Set",
              "Barcode assigned to stock item",
              onDismissed: () {
                _controller.dispose();
                Navigator.of(_context).pop();
              }
          );
        } else {
          showErrorDialog(
            _context,
            "Server Error",
            "Could not assign barcode",
            onDismissed: () {
              _controller.resumeCamera();
            }
          );
        }
      });
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

  _QRViewState(this._handler) : super();

  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  void _onViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scandata) {
      _controller?.pauseCamera();
      _handler.processBarcode(context, _controller, scandata);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // Save the context for later on!
    this.context = context;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Expanded(
            flex: 4,
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


class StockItemScanIntoLocationHandler extends BarcodeHandler {
  /**
   * Barcode handler for scanning a provided StockItem into a scanned StockLocation
   */

  final InvenTreeStockItem item;

  StockItemScanIntoLocationHandler(this.item);

  @override
  String getOverlayText(BuildContext context) => I18N.of(context).barcodeScanLocation;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) {
    // If the barcode points to a 'stocklocation', great!
    if (data.containsKey('stocklocation')) {
      // Extract location information
      int location = data['stocklocation']['pk'] as int;

      // Transfer stock to specified location
      item.transferStock(location).then((response) {
        print("Response: ${response.statusCode}");
        _controller.dispose();
        Navigator.of(_context).pop();
      });
    } else {
      // Display a snack bar with the error
      OneContext().showSnackBar(builder: (context) => SnackBar(
        content: Text("This was not a stock item!")
      ));
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
  Future<void> onBarcodeMatched(Map<String, dynamic> data) {
    print("TODO, YO!");
  }
}


Future<void> scanQrCode(BuildContext context) async {

  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeQRView(BarcodeScanHandler())));

  return;
}