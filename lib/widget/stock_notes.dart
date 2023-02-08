
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:flutter_markdown/flutter_markdown.dart";
import "package:inventree/l10.dart";

import "package:inventree/api.dart";


class StockNotesWidget extends StatefulWidget {

  const StockNotesWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockNotesState createState() => _StockNotesState(item);
}


class _StockNotesState extends RefreshableState<StockNotesWidget> {

  _StockNotesState(this.item);

  final InvenTreeStockItem item;

  @override
  String getAppBarTitle(BuildContext context) => L10().stockItemNotes;

  @override
  Future<void> request(BuildContext context) async {
    if (item.pk > 0) {
      await item.reload();
    }
  }

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission("stock", "change")) {
      actions.add(
          IconButton(
              icon: FaIcon(FontAwesomeIcons.penToSquare),
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
                    refresh(context);
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