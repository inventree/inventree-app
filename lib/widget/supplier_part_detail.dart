import "package:flutter/material.dart";

import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import 'package:inventree/widget/progress.dart';

import "package:inventree/widget/refreshable_state.dart";


/*
 * Detail widget for viewing a single SupplierPart instance
 */
class SupplierPartDetailWidget extends StatefulWidget {

  const SupplierPartDetailWidget(this.supplierPart, {Key? key}) : super(key: key);

  final InvenTreeSupplierPart supplierPart;

  @override
  _SupplierPartDisplayState createState() => _SupplierPartDisplayState();
}


class _SupplierPartDisplayState extends RefreshableState<SupplierPartDetailWidget> {

  _SupplierPartDisplayState();

  @override
  String getAppBarTitle(BuildContext context) => L10().supplierPart;

  @override
  Future<void> request(BuildContext context) async {
    final bool result = widget.supplierPart.pk > 0 && await widget.supplierPart.reload();

    if (!result) {
      Navigator.of(context).pop();
    }
  }

  /*
   * Build a set of tiles to display for this SupplierPart
   */
  List<Widget> detailTiles(BuildContext context) {
    List<Widget> tiles = [];

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    return tiles;
  }

  /*
   * Build the widget
   */
  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: ListTile.divideTiles(
        context: context,
        tiles: detailTiles(context),
      ).toList()
    );
  }

}