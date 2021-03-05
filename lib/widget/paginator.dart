// Pagination related widgets

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PaginatedSearchWidget extends StatelessWidget {

  Function onChanged;

  int results = 0;

  TextEditingController controller;

  PaginatedSearchWidget(this.controller, this.onChanged, this.results);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        child: FaIcon(controller.text.isEmpty ? FontAwesomeIcons.search : FontAwesomeIcons.backspace),
        onTap: () {
          if (onChanged != null) {
            controller.clear();
            onChanged();
          }
        },
      ),
      title: TextFormField(
        controller: controller,
        onChanged: (value) {

          if (onChanged != null) {
            onChanged();
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
