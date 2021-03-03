// Pagination related widgets

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PaginatedSearch extends StatelessWidget {

  Function callback;

  PaginatedSearch({this.callback});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: TextField(
          onChanged: callback,
          decoration: InputDecoration(
            hintText: "Search",
          ),
      )
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

