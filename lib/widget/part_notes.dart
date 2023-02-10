import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:flutter_markdown/flutter_markdown.dart";
import "package:inventree/l10.dart";


class PartNotesWidget extends StatefulWidget {

  const PartNotesWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartNotesState createState() => _PartNotesState(part);
}


class _PartNotesState extends RefreshableState<PartNotesWidget> {

  _PartNotesState(this.part);

  final InvenTreePart part;

  @override
  Future<void> request(BuildContext context) async {
    await part.reload();
  }

  @override
  String getAppBarTitle(BuildContext context) => L10().partNotes;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission("part", "change")) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.penToSquare),
          tooltip: L10().edit,
          onPressed: () {
            part.editForm(
              context,
              L10().editNotes,
              fields: {
                "notes": {
                  "multiline": true,
                }
              },
              onSuccess: (data) async {
                refresh(context);
              }
            );
          }
        )
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return Markdown(
      selectable: false,
      data: part.notes,
    );
  }

}