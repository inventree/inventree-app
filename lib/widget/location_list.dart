import "package:flutter/material.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/widget/location_display.dart";
import "package:inventree/widget/paginator.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";


class StockLocationList extends StatefulWidget {

  const StockLocationList(this.filters);

  final Map<String, String> filters;

  @override
  _StockLocationListState createState() => _StockLocationListState(filters);
}


class _StockLocationListState extends RefreshableState<StockLocationList> {

  _StockLocationListState(this.filters);

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => L10().stockLocations;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedStockLocationList(filters, true);
  }
}


class PaginatedStockLocationList extends PaginatedSearchWidget {

  const PaginatedStockLocationList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedStockLocationListState createState() => _PaginatedStockLocationListState();
}


class _PaginatedStockLocationListState extends PaginatedSearchState<PaginatedStockLocationList> {

  _PaginatedStockLocationListState() : super();

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final page = await InvenTreeStockLocation().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreeStockLocation location = model as InvenTreeStockLocation;

    return ListTile(
      title: Text(location.name),
      subtitle: Text(location.pathstring),
      trailing: Text("${location.itemcount}"),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationDisplayWidget(location)
          )
        );
      },
    );
  }
}