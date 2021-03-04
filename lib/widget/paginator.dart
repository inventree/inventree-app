// Pagination related widgets

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PaginatedSearch extends StatelessWidget {

  Function callback;

  int results = 0;

  PaginatedSearch({this.callback, this.results});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FaIcon(FontAwesomeIcons.search),
      title: TextField(
        onChanged: (value) {
          if (callback != null) {
            callback(value);
          }
        },
        decoration: InputDecoration(
          hintText: "Search parts",
        ),
      ),
      trailing: Text(
        "${results}",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class NoResultsWidget extends StatelessWidget {

  final String description;

  NoResultsWidget(this.description);

  @override
  Widget build(BuildContext context) {

    return ListTile(
      title: Text(I18N.of(context).noResults),
      subtitle: Text(description),
      leading: FaIcon(FontAwesomeIcons.exclamationCircle),
    );
  }

}
