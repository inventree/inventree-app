import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_utils/qr_utils.dart';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';

import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_display.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/stock_display.dart';

import 'dart:convert';

void scanQrCode(BuildContext context) async {

  QrUtils.scanQR.then((String result) {

    print("Scanned: $result");

    // Look for JSON data in the result...
    final data = json.decode(result);

    // Look for an 'InvenTree' style barcode
    if ((data['tool'] ?? '').toString().toLowerCase() == 'inventree') {
      _handleInvenTreeBarcode(context, data);
    }

    // Unknown barcode style!
    else {
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

  });
}

void _handleInvenTreeBarcode(BuildContext context, Map<String, dynamic> data) {

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
    InvenTreeStockItem().get(pk).then((var item) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => StockItemDisplayWidget(item)));
    });
  } else if (codeType == 'part') {
    InvenTreePart().get(pk).then((var part) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => PartDisplayWidget(part)));
    });
  }
}