
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/inventree/stock.dart';
import 'package:inventree/widget/refreshable_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:inventree/l10.dart';

import '../api.dart';


class StockNotesWidget extends StatefulWidget {

  final InvenTreeStockItem item;

  StockNotesWidget(this.item, {Key? key}) : super(key: key);

  @override
  _StockNotesState createState() => _StockNotesState(item);
}


class _StockNotesState extends RefreshableState<StockNotesWidget> {

  final InvenTreeStockItem item;

  _StockNotesState(this.item);

  @override
  String getAppBarTitle(BuildContext context) => L10().stockItemNotes;

  @override
  Future<void> request() async {
    await item.reload();
  }

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission('stock', 'change')) {
      actions.add(
          IconButton(
              icon: FaIcon(FontAwesomeIcons.edit),
              tooltip: L10().edit,
              onPressed: () {
                item.editForm(
                  context,
                  L10().editNotes,
                  fields: {
                    "notes": {
                      "multiline": true,
                    }
                  },
                  onSuccess: (data) async {
                    refresh();
                  }
                );
              }
          )
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return Markdown(
      selectable: false,
      data: item.notes,
    );
  }

}