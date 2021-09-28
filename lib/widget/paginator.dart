import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/l10.dart";


class PaginatedSearchWidget extends StatelessWidget {

  const PaginatedSearchWidget(this.controller, this.onChanged, this.results);

  final Function onChanged;

  final int results;

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        child: FaIcon(controller.text.isEmpty ? FontAwesomeIcons.search : FontAwesomeIcons.backspace),
        onTap: () {
          controller.clear();
          onChanged();
        },
      ),
      title: TextFormField(
        controller: controller,
        onChanged: (value) {
          onChanged();
        },
        decoration: InputDecoration(
          hintText: L10().search,
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

  const NoResultsWidget(this.description);

  final String description;

  @override
  Widget build(BuildContext context) {

    return ListTile(
      title: Text(L10().noResults),
      subtitle: Text(description),
      leading: FaIcon(FontAwesomeIcons.exclamationCircle),
    );
  }

}
