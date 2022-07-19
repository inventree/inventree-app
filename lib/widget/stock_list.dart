import "package:flutter/material.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/stock_detail.dart";
import "package:inventree/api.dart";


class StockItemList extends StatefulWidget {

  const StockItemList(this.filters);

  final Map<String, String> filters;

  @override
  _StockListState createState() => _StockListState(filters);
}


class _StockListState extends RefreshableState<StockItemList> {

  _StockListState(this.filters);

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => L10().stockItems;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedStockItemList(filters, true);
  }
}

class PaginatedStockItemList extends PaginatedSearchWidget {

  const PaginatedStockItemList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedStockItemListState createState() => _PaginatedStockItemListState();
  
}


class _PaginatedStockItemListState extends PaginatedSearchState<PaginatedStockItemList> {

  _PaginatedStockItemListState() : super();

  @override
  String get prefix => "stock_";

  @override
  Map<String, String> get orderingOptions => {
    "part__name": L10().name,
    "part__IPN": L10().internalPartNumber,
    "stock": L10().quantity,
    "status": L10().status,
    "batch": L10().batchCode,
    "updated": L10().lastUpdated,
    "stocktake_date": L10().lastStocktake,
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final page = await InvenTreeStockItem().listPaginated(
      limit,
      offset,
      filters: params
    );

    return page;
  }

  void _openItem(BuildContext context, int pk) {
    InvenTreeStockItem().get(pk).then((var item) {
      if (item is InvenTreeStockItem) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
      }
    });
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreeStockItem item = model as InvenTreeStockItem;

    return ListTile(
      title: Text("${item.partName}"),
      subtitle: Text("${item.locationPathString}"),
      leading: InvenTreeAPI().getImage(
        item.partThumbnail,
        width: 40,
        height: 40,
      ),
      trailing: Text("${item.displayQuantity}",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: item.statusColor,
        ),
      ),
      onTap: () {
        _openItem(context, item.pk);
      },
    );
  }
}