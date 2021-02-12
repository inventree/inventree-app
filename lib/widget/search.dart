
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/progress.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/inventree/stock.dart';

import '../api.dart';


class PartSearchDelegate extends SearchDelegate<InvenTreePart> {

  final key = GlobalKey<ScaffoldState>();

  bool _searching = false;

  // List of part results
  List<InvenTreePart> partResults = [];

  Future<void> search(BuildContext context) async {

    // Search string too short!
    if (query.length < 3) {
      partResults.clear();
      showResults(context);
      return;
    }

    _searching = true;

    print("Searching...");

    showResults(context);

    final results = await InvenTreePart().search(context, query);

    partResults.clear();

    for (int idx = 0; idx < results.length; idx++) {
      if (results[idx] is InvenTreePart) {
        partResults.add(results[idx]);
      }
    }

    print("Searching complete! Results: ${partResults.length}");
    _searching = false;

    // TODO: Show a snackbar detailing number of results...
    //showSnackIcon("Found ${partResults.length} parts", context: context);

    // For some reason, need to toggle between suggestions and results here...
    showSuggestions(context);
    showResults(context);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
          icon: FaIcon(FontAwesomeIcons.search),
          onPressed: () {
            search(context);
          }
      ),
      IconButton(
        icon: FaIcon(FontAwesomeIcons.backspace),
        onPressed: () {
          query = '';
          search(context);
        },
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

    print("Build results called...");

    if (_searching) {
      return progressIndicator();
    }

    if (query.length < 3) {
      return ListTile(
        title: Text("Query too short"),
        subtitle: Text("Enter a query of at least three characters")
      );
    }

    if (partResults.length == 0) {
      return ListTile(
        title: Text("No Results"),
        subtitle: Text("No results matching query")
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


class SearchWidget extends StatefulWidget {

  @override
  _SearchState createState() => _SearchState();
}


class _SearchState extends RefreshableState<SearchWidget> {

  String _searchText = "";

  List<InvenTreePart> _parts = List<InvenTreePart>();
  List<InvenTreeStockItem> _stockItems = List<InvenTreeStockItem>();

  @override
  String getAppBarTitle(BuildContext context) => I18N.of(context).search;

  Future<void> _search(BuildContext context) {
    print("Search: $_searchText}");

    // Ignore if the search text is empty
    if (_searchText.isNotEmpty) {

      // Search for parts
      InvenTreePart().list(context, filters: {"search": _searchText}).then((var parts) {
        setState(() {
          _parts.clear();
          for (var part in parts) {
            if (part is InvenTreePart) {
              _parts.add(part);
            }
          }

          print("Matched ${_parts.length} parts");
        });
      });

      // Search for stock items
      InvenTreeStockItem().list(context, filters: {"search": _searchText}).then((var items) {
        setState(() {
          _stockItems.clear();
          for (var item in items) {
            if (item is InvenTreeStockItem) {
              _stockItems.add(item);
            }
          }

          print("Matched ${_stockItems.length} stock items");
        });
      });
    }
  }

  @override
  Future<void> request(BuildContext context) async {
    _search(context);
  }

  @override
  Widget getBody(BuildContext context) {

    return Center(
      child: ListView(
        children: <Widget>[
          TextField(
            decoration: InputDecoration(
              hintText: I18N.of(context).search,
            ),
            onChanged: (String text) {
              _searchText = text;
            }
          ),
          RaisedButton(
            child: Text(I18N.of(context).search),
            onPressed: () {
              _search(context);
            },
          ),
        ]
      )
    );
  }
}