

import 'package:InvenTree/inventree/stock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StockItemDisplayWidget extends StatefulWidget {

  StockItemDisplayWidget(this.item, {Key key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState(item);
}


class _StockItemDisplayState extends State<StockItemDisplayWidget> {

  _StockItemDisplayState(this.item) {
    // TODO
  }

  final InvenTreeStockItem item;

  String get _title {
    if (item == null) {
      return "Stock Item";
    } else {
      print(item.jsondata);
      return "Item: x ${item.partName}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Stock Item: hello"),
          ],
        )
      )
    );
  }
}