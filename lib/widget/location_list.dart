import "package:flutter/cupertino.dart";
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
    return PaginatedStockLocationList(filters);
  }
}


class PaginatedStockLocationList extends StatefulWidget {

  const PaginatedStockLocationList(this.filters);

  final Map<String, String> filters;

  @override
  _PaginatedStockLocationListState createState() => _PaginatedStockLocationListState(filters);
}


class _PaginatedStockLocationListState extends PaginatedSearchState<PaginatedStockLocationList> {

  _PaginatedStockLocationListState(Map<String, String> filters) : super(filters);

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