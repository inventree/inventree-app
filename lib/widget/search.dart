
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

  // Custom filters for the part search
  Map<String, String> filters = {};

  PartSearchDelegate({this.filters}) {
    if (filters == null) {
      filters = {};
    }
  }

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