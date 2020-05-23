import 'package:InvenTree/widget/dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

//import 'package:qr_utils/qr_utils.dart';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/stock_detail.dart';

import 'dart:convert';

Future<void> scanQrCode(BuildContext context) async {

  return;
  /*
  QrUtils.scanQR.then((String barcode) {

    print("Scanned: $barcode");

    showProgressDialog(context, "Querying Server", "Sending barcode data to server");

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
  });
  */
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