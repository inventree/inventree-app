import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_utils/qr_utils.dart';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/widget/location_display.dart';

import 'dart:convert';

void scanQrCode(BuildContext context) async {

  QrUtils.scanQR.then((String result) {
    // Look for JSON data in the result...
    final data = json.decode(result);

    final String tool = (data['tool'] ?? '').toString().toLowerCase();

    // This looks like an InvenTree QR code!
    if (tool == 'inventree') {
      final String codeType = (data['type'] ?? '').toString().toLowerCase();

      final int pk = (data['id'] ?? -1) as int;

      if (codeType == 'stocklocation') {

        // Try to open a stock location...
        InvenTreeStockLocation().get(pk).then((var loc) {
          if (loc is InvenTreeStockLocation) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
          }
        });

      } else if (codeType == 'stockitem') {

      }


    } else {
     showDialog(
       context: context,
       child: new SimpleDialog(
         title: new Text("Unknown barcode"),
         children: <Widget>[
           Text("Data: $result"),
         ]
       )
     );
    }

    print("Scanned: $result");
  });
}