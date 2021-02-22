
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/progress.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:InvenTree/widget/stock_detail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:one_context/one_context.dart';

import '../api.dart';

// TODO - Refactor duplicate code in this file!

class PartSearchDelegate extends SearchDelegate<InvenTreePart> {

  final key = GlobalKey<ScaffoldState>();

  BuildContext context;

  // What did we search for last time?
  String _cachedQuery;

  bool _searching = false;

  // Custom filters for the part search
  Map<String, String> filters = {};

  PartSearchDelegate(this.context, {this.filters}) {
    if (filters == null) {
      filters = {};
    }
  }

  @override
  String get searchFieldLabel => I18N.of(context).searchParts;

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

    // Enable cascading part search by default
    filters["cascade"] = "true";

    final results = await InvenTreePart().search(context, query, filters: filters);

    partResults.clear();

    for (int idx = 0; idx < results.length; idx++) {
      if (results[idx] is InvenTreePart) {
        partResults.add(results[idx]);
      }
    }

    print("Searching complete! Results: ${partResults.length}");
    _searching = false;

    showSnackIcon(
        "${partResults.length} ${I18N.of(OneContext().context).results}",
        success: partResults.length > 0,
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
          query = '';
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
        this.close(context, null);
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
        InvenTreePart().get(context, part.pk).then((var prt) {
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

    if (query.length == 0) {
      return ListTile(
        title: Text("Enter search query")
      );
    }

    if (query.length < 3) {
      return ListTile(
        title: Text("Query too short"),
        subtitle: Text("Enter a query of at least three characters")
      );
    }

    if (partResults.length == 0) {
      return ListTile(
        title: Text(I18N.of(context).noResults),
        subtitle: Text("No results for '${query}'")
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
    assert(context != null);
    final ThemeData theme = Theme.of(context);
    assert(theme != null);
    return theme;
  }
}


class StockSearchDelegate extends SearchDelegate<InvenTreeStockItem> {

  final key = GlobalKey<ScaffoldState>();

  final BuildContext context;

  String _cachedQuery;

  bool _searching = false;

  // Custom filters for the stock item search
  Map<String, String> filters;

  StockSearchDelegate(this.context, {this.filters}) {
    if (filters == null) {
      filters = {};
    }
  }

  @override
  String get searchFieldLabel => I18N.of(context).searchStock;

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
    filters["cascade"] = "true";

    final results = await InvenTreeStockItem().search(
        context, query, filters: filters);

    itemResults.clear();

    for (int idx = 0; idx < results.length; idx++) {
      if (results[idx] is InvenTreeStockItem) {
        itemResults.add(results[idx]);
      }
    }

    _searching = false;

    showSnackIcon(
      "${itemResults.length} ${I18N.of(OneContext().context).results}",
      success: itemResults.length > 0,
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
          query = '';
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
          this.close(context, null);
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
        InvenTreeStockItem().get(context, item.pk).then((var it) {
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

    if (query.length == 0) {
      return ListTile(
          title: Text("Enter search query")
      );
    }

    if (query.length < 3) {
      return ListTile(
          title: Text("Query too short"),
          subtitle: Text("Enter a query of at least three characters")
      );
    }

    if (itemResults.length == 0) {
      return ListTile(
          title: Text(I18N.of(context).noResults),
          subtitle: Text("No results for '${query}'")
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
    assert(context != null);
    final ThemeData theme = Theme.of(context);
    assert(theme != null);
    return theme;
  }
}