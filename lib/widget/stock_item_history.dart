

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:inventree/widget/refreshable_state.dart';
import 'package:inventree/l10.dart';
import 'package:inventree/inventree/stock.dart';

class StockItemHistoryWidget extends StatefulWidget {

  const StockItemHistoryWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemHistoryDisplayState createState() => _StockItemHistoryDisplayState(item);
}


class _StockItemHistoryDisplayState extends RefreshableState<StockItemHistoryWidget> {

  _StockItemHistoryDisplayState(this.item);

  final InvenTreeStockItem item;

  @override
  String getAppBarTitle(BuildContext context) => L10().stockItemHistory;

  @override
  Future<void> request(BuildContext refresh) async {
    // TODO
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: ListTile.divideTiles(
        context: context,
        tiles: [],
      ).toList()
    );
  }
}