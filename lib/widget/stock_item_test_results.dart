import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/api.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:InvenTree/widget/refreshable_state.dart';

class StockItemTestResultsWidget extends StatefulWidget {

  StockItemTestResultsWidget(this.item, {Key key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemTestResultDisplayState createState() => _StockItemTestResultDisplayState(item);
}


class _StockItemTestResultDisplayState extends RefreshableState<StockItemTestResultsWidget> {

  @override
  String getAppBarTitle(BuildContext context) { return "Test Results"; }

  @override
  Future<void> request(BuildContext context) async {
    await item.getTestTemplates(context);
    await item.getTestResults(context);
  }

  final InvenTreeStockItem item;

  _StockItemTestResultDisplayState(this.item);

  // Squish together templates and results

  List<Widget> resultsList() {
    List<Widget> items = [];

    items.add(ListTile(
        title: Text("Test results"),
    ));

    return items;
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: resultsList(),
    );
  }
}