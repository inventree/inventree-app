


import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


class StockNotesWidget extends StatefulWidget {

  final InvenTreeStockItem item;

  StockNotesWidget(this.item, {Key key}) : super(key: key);

  @override
  _StockNotesState createState() => _StockNotesState(item);
}


class _StockNotesState extends RefreshableState<StockNotesWidget> {

  final InvenTreeStockItem item;

  _StockNotesState(this.item);

  @override
  String getAppBarTitle(BuildContext context) => I18N.of(context).stockItemNotes;

  @override
  Widget getBody(BuildContext context) {
    return Markdown(
      selectable: false,
      data: item.notes,
    );
  }

}