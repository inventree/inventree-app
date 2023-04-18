import "package:flutter/material.dart";
import "package:inventree/api.dart";

import "package:inventree/l10.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/model.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";


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
  String getAppBarTitle() => L10().stockItemHistory;

  List<InvenTreeStockItemHistory> history = [];

  @override
  Future<void> request(BuildContext refresh) async {

    history.clear();

    await InvenTreeStockItemHistory().list(filters: {"item": "${item.pk}"}).then((List<InvenTreeModel> results) {
      for (var result in results) {
        if (result is InvenTreeStockItemHistory) {
          history.add(result);
        }
      }

      // Refresh
      setState(() {
      });
    });
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: ListTile.divideTiles(
        context: context,
        tiles: historyList(),
    ).toList());
  }

  List<Widget> historyList() {
    List<Widget> tiles = [];

    for (var entry in history) {
      tiles.add(ListTile(
          leading: Text(entry.dateString),
        trailing:
            entry.quantityString.isNotEmpty ? Text(entry.quantityString) : null,
          title: Text(entry.label),
          subtitle: entry.notes.isNotEmpty ? Text(entry.notes) : null,
      ));
    }

    return tiles;
  }
}
/*
 * Widget which displays a paginated stock history list
 */
class PaginatedStockHistoryList extends PaginatedSearchWidget {
  const PaginatedStockHistoryList(Map<String, String> filters, bool showSearch)
      : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedStockHistoryState createState() => _PaginatedStockHistoryState();
}

/*
 * State class for the paginated stock history list
 */
class _PaginatedStockHistoryState extends PaginatedSearchState<PaginatedStockHistoryList> {
  
  _PaginatedStockHistoryState() : super();

  @override
  String get prefix => "stock_history";

  @override
  Map<String, String> get orderingOptions => {};

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
        // TODO: Add filter options
      };

  @override
  Future<InvenTreePageResponse?> requestPage(
      int limit, int offset, Map<String, String> params) async {
    await InvenTreeAPI().StockHistoryStatus.load();

    final page = await InvenTreeStockItemHistory()
        .listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeStockItemHistory entry = model as InvenTreeStockItemHistory;

    return ListTile(
      leading: Text(entry.dateString),
      trailing:
          entry.quantityString.isNotEmpty ? Text(entry.quantityString) : null,
      title: Text(entry.label),
      subtitle: entry.notes.isNotEmpty ? Text(entry.notes) : null,
    );
  }
}
