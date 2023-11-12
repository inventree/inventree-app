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

  @override
  List<Widget> appBarActions(BuildContext context) => [];

  @override
  Widget getBody(BuildContext context) {
    Map<String, String> filters = {
      "item": widget.item.pk.toString(),
    };

    return PaginatedStockHistoryList(filters);
  }

}

/*
 * Widget which displays a paginated stock history list
 */
class PaginatedStockHistoryList extends PaginatedSearchWidget {
  const PaginatedStockHistoryList(Map<String, String> filters) : super(filters: filters);

  @override
  String get searchTitle => L10().stockItemHistory;

  @override
  _PaginatedStockHistoryState createState() => _PaginatedStockHistoryState();
}

/*
 * State class for the paginated stock history list
 */
class _PaginatedStockHistoryState
    extends PaginatedSearchState<PaginatedStockHistoryList> {
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

    final page = await InvenTreeStockItemHistory().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeStockItemHistory entry = model as InvenTreeStockItemHistory;

    return ListTile(
      leading: Text(entry.dateString),
      trailing: entry.userString.isNotEmpty ? Text(entry.userString) : null,
      title: Text(entry.label),
      subtitle: entry.notes.isNotEmpty ? Text(entry.notes) : null,
    );
  }
}
