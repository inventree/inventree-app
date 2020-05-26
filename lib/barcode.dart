import 'package:InvenTree/widget/dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

//import 'package:qr_utils/qr_utils.dart';
//import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
//import 'package:barcode_scan/barcode_scan.dart';

import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/stock_detail.dart';

import 'dart:convert';


class InvenTreeQRView extends StatefulWidget {

  InvenTreeQRView({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewState();
}


class _QRViewState extends State<InvenTreeQRView> {

  QRViewController _controller;

  BuildContext context;

  _QRViewState() : super();

  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  Future<void> processBarcode(String barcode) async {
    if (barcode == null || barcode.isEmpty) {
      return;
    }

    print("Scanned: ${barcode}");
    showProgressDialog(context, "Querying server", "Sending barcode data to server");

    InvenTreeAPI().post("barcode/", body: {"barcode": barcode}).then((var response) {
      hideProgressDialog(context);

      print("Response:");
      print(response.body);
    }).timeout(
        Duration(seconds: 5)
    ).catchError((error) {
      hideProgressDialog(context);
      showErrorDialog(context, "Error", error.toString());
      return;
    });

  }

  void _onViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scandata) {
      processBarcode(scandata);
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
      body: Column(
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
          )
        ],
      )
    );
  }
}


Future<void> scanQrCode(BuildContext context) async {

  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeQRView()));

  return;
  /*
  print("Scanning");
  String barcode = await FlutterBarcodeScanner.scanBarcode("#F00", "Cancel", false, ScanMode.DEFAULT);
  print("and, DONE");
  if (barcode == null || barcode.isEmpty) {
    return;
  }

  print("Scanned: $barcode");

  showProgressDialog(context, "Querying Server", "Sending barcode data to server");
  */

  String barcode = null;
  /*
   * POST the scanned barcode data to the server.
   * It is the responsibility of the server to validate and sanitize the barcode data,
   * and return a "common" response that we know how to deal with.
   */
  InvenTreeAPI().post("barcode/", body: {"barcode": barcode}).then((var response) {

    hideProgressDialog(context);

    if (response.statusCode != 200) {
      showDialog(
        context: context,
        child: new SimpleDialog(
          title: Text("Server Error"),
          children: <Widget>[
            ListTile(
              title: Text("Error ${response.statusCode}"),
              subtitle: Text("${response.body.toString().split("\n").first}"),
            )
          ],
        ),
      );

      return;
    }

    final Map<String, dynamic> body = json.decode(response.body);

    // TODO - Handle potential error decoding response

    print("Barcode response:");
    print(body.toString());

    if (body.containsKey('error')) {
      showDialog(
        context: context,
        child: new SimpleDialog(
          title: Text("Barcode Error"),
          children: <Widget>[
            ListTile(
              title: Text("${body['error']}"),
              subtitle: Text("Plugin: ${body['plugin'] ?? '<no plugin information>'}"),
            )
          ],
        )
      );
    } else if (body.containsKey('success')) {
      // Decode the barcode!
      // Ideally, the server has returned unto us something sensible...
      _handleBarcode(context, body);
    } else {
      showDialog(
        context: context,
        child: new SimpleDialog(
          title: Text("Unknown response"),
          children: <Widget>[
            ListTile(
              title: Text("Response data"),
              subtitle: Text("${body.toString()}"),
            )
          ],
        )
      );
    }

    print("body: ${body.toString()}");

  });
}

void _handleBarcode(BuildContext context, Map<String, dynamic> data) {

  int pk;

  // A stocklocation has been passed?
  if (data.containsKey('stocklocation')) {

    pk = data['stocklocation']['pk'] as int ?? null;

    if (pk != null) {
      InvenTreeStockLocation().get(context, pk).then((var loc) {
        if (loc is InvenTreeStockLocation) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
        }
      });
    } else {
      // TODO - Show an error here!
    }

  } else if (data.containsKey('stockitem')) {

    pk = data['stockitem']['pk'] as int ?? null;

    if (pk != null) {
      InvenTreeStockItem().get(context, pk).then((var item) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
      });
    } else {
      // TODO - Show an error here!
    }
  } else if (data.containsKey('part')) {

    pk = data['part']['pk'] as int ?? null;

    if (pk != null) {
      InvenTreePart().get(context, pk).then((var part) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
      });
    } else {
      // TODO - Show an error here!
    }
  } else {
    showDialog(
      context: context,
      child: SimpleDialog(
        title: Text("Unknown response"),
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