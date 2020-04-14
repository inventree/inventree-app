import 'package:InvenTree/widget/dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_utils/qr_utils.dart';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/stock_detail.dart';

import 'dart:convert';

Future<void> scanQrCode(BuildContext context) async {

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
}

void _handleBarcode(BuildContext context, Map<String, dynamic> data) {

  int id;

  // A stocklocation has been passed?
  if (data.containsKey('stocklocation')) {

    id = data['stocklocation']['id'] ?? null;

    if (id != null) {
      InvenTreeStockLocation().get(context, id).then((var loc) {
        if (loc is InvenTreeStockLocation) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
        }
      });
    }

  } else if (data.containsKey('stockitem')) {

    id = data['stockitem']['id'] ?? null;

    if (id != null) {
      InvenTreeStockItem().get(context, id).then((var item) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
      });
    }
  } else if (data.containsKey('part')) {

    id = data['part']['id'] ?? null;

    if (id != null) {
      InvenTreePart().get(context, id).then((var part) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
      });
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