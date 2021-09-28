
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock_detail.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/api.dart";

// TODO - Refactor duplicate code in this file!

class PartSearchDelegate extends SearchDelegate<InvenTreePart?> {

  PartSearchDelegate(this.context, {Map<String, String> filters = const {}}) {

    // Copy filter values
    for (String key in filters.keys) {

      String? value = filters[key];

      if (value != null) {
        _filters[key] = value;
      }
    }
  }

  final partSearchKey = GlobalKey<ScaffoldState>();

  BuildContext context;

  // What did we search for last time?
  String _cachedQuery = "";

  bool _searching = false;

  // Custom filters for the part search
  Map<String, String> _filters = {};

  @override
  String get searchFieldLabel => L10().searchParts;

  // List of part results
  List<InvenTreePart> partResults = [];

  Future<void> search(BuildContext context) async {

    // Search string too short!
    if (query.length < 3) {
      partResults.clear();
      showResults(context);
      return;
    }

    if (query == _cachedQuery) {
      return;
    }

    _cachedQuery = query;

    _searching = true;

    print("Searching...");

    showResults(context);

    _filters["cascade"] = "true";

    final results = await InvenTreePart().search(context, query, filters: _filters);

    partResults.clear();

    for (int idx = 0; idx < results.length; idx++) {
      if (results[idx] is InvenTreePart) {
        partResults.add(results[idx] as InvenTreePart);
      }
    }

    print("Searching complete! Results: ${partResults.length}");
    _searching = false;

    showSnackIcon(
        "${partResults.length} ${L10().results}",
        success: partResults.isNotEmpty,
        icon: FontAwesomeIcons.pollH,
    );

    // For some reason, need to toggle between suggestions and results here...
    showSuggestions(context);
    showResults(context);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: FaIcon(FontAwesomeIcons.backspace),
        onPressed: () {
          query = "";
          search(context);
        },
      ),
      IconButton(
        icon: FaIcon(FontAwesomeIcons.search),
        onPressed: () {
          search(context);
        }
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      }
    );
  }

  Widget _partResult(BuildContext context, int index) {

    InvenTreePart part = partResults[index];

    return ListTile(
      title: Text(part.fullname),
      subtitle: Text(part.description),
      leading: InvenTreeAPI().getImage(
        part.thumbnail,
        width: 40,
        height: 40
      ),
      trailing: Text(part.inStockString),
      onTap: () {
        InvenTreePart().get(part.pk).then((var prt) {
          if (prt is InvenTreePart) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PartDetailWidget(prt))
            );
          }
        });
      }
    );
  }

  @override
  Widget buildResults(BuildContext context) {

    print("build results");

    if (_searching) {
      return progressIndicator();
    }

    search(context);

    if (query.isEmpty) {
      return ListTile(
        title: Text(L10().queryEnter)
      );
    }

    if (query.length < 3) {
      return ListTile(
        title: Text(L10().queryShort),
        subtitle: Text(L10().queryShortDetail)
      );
    }

    if (partResults.isEmpty) {
      return ListTile(
        title: Text(L10().noResults),
        subtitle: Text(L10().queryNoResults + " '${query}'")
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      separatorBuilder: (_, __) => const Divider(height: 3),
      itemBuilder: _partResult,
      itemCount: partResults.length,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // TODO - Implement
    return Column();
  }

  // Ensure the search theme matches the app theme
  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme;
  }
}


class StockSearchDelegate extends SearchDelegate<InvenTreeStockItem?> {

  StockSearchDelegate(this.context, {Map<String, String> filters = const {}}) {

    // Copy filter values
    for (String key in filters.keys) {

      String? value = filters[key];

      if (value != null) {
        _filters[key] = value;
      }
    }
  }

  final stockSearchKey = GlobalKey<ScaffoldState>();

  final BuildContext context;

  String _cachedQuery = "";

  bool _searching = false;

  // Custom filters for the stock item search
  Map<String, String> _filters = {};

  @override
  String get searchFieldLabel => L10().searchStock;

  // List of StockItem results
  List<InvenTreeStockItem> itemResults = [];

  Future<void> search(BuildContext context) async {
    // Search string too short!
    if (query.length < 3) {
      itemResults.clear();
      showResults(context);
      return;
    }

    if (query == _cachedQuery) {
      return;
    }

    _cachedQuery = query;

    _searching = true;

    print("Searching...");

    showResults(context);

    // Enable cascading part search by default
    _filters["cascade"] = "true";

    final results = await InvenTreeStockItem().search(
        context, query, filters: _filters);

    itemResults.clear();

    for (int idx = 0; idx < results.length; idx++) {
      if (results[idx] is InvenTreeStockItem) {
        itemResults.add(results[idx] as InvenTreeStockItem);
      }
    }

    _searching = false;

    showSnackIcon(
      "${itemResults.length} ${L10().results}",
      success: itemResults.isNotEmpty,
      icon: FontAwesomeIcons.pollH,
    );

    showSuggestions(context);
    showResults(context);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: FaIcon(FontAwesomeIcons.backspace),
        onPressed: () {
          query = "";
          search(context);
        },
      ),
      IconButton(
          icon: FaIcon(FontAwesomeIcons.search),
          onPressed: () {
            search(context);
          }
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () {
          close(context, null);
        }
    );
  }

  Widget _itemResult(BuildContext context, int index) {

    InvenTreeStockItem item = itemResults[index];

    return ListTile(
      title: Text(item.partName),
      subtitle: Text(item.locationName),
      leading: InvenTreeAPI().getImage(
        item.partThumbnail,
        width: 40,
        height: 40,
      ),
      trailing: Text(item.serialOrQuantityDisplay()),
      onTap: () {
        InvenTreeStockItem().get(item.pk).then((var it) {
          if (it is InvenTreeStockItem) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StockDetailWidget(it))
            );
          }
        });
      }
    );
  }

  @override
  Widget buildResults(BuildContext context) {

    search(context);

    if (_searching) {
      return progressIndicator();
    }

    search(context);

    if (query.isEmpty) {
      return ListTile(
          title: Text(L10().queryEnter)
      );
    }

    if (query.length < 3) {
      return ListTile(
          title: Text(L10().queryShort),
          subtitle: Text(L10().queryShortDetail)
      );
    }

    if (itemResults.isEmpty) {
      return ListTile(
          title: Text(L10().noResults),
          subtitle: Text(L10().queryNoResults + " '${query}'")
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      separatorBuilder: (_, __) => const Divider(height: 3),
      itemBuilder: _itemResult,
      itemCount: itemResults.length,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // TODO - Implement
    return Column();
  }

  // Ensure the search theme matches the app theme
  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme;
  }
}