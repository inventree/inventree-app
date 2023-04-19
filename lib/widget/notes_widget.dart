import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:flutter_markdown/flutter_markdown.dart";
import "package:inventree/l10.dart";


/*
 * A widget for displaying the notes associated with a given model.
 * We need to pass in the following parameters:
 * 
 * - Model instance
 * - Title for the app bar
 */
class NotesWidget extends StatefulWidget {

  const NotesWidget(this.model, {Key? key}) : super(key: key);

  final InvenTreeModel model;

  @override
  _NotesState createState() => _NotesState();
}


/*
 * Class representing the state of the NotesWidget
 */
class _NotesState extends RefreshableState<NotesWidget> {

  _NotesState();

  @override
  Future<void> request(BuildContext context) async {
    await widget.model.reload();
  }

  @override
  String getAppBarTitle() => L10().editNotes;

  @override
  List<Widget> appBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (widget.model.canEdit) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.penToSquare),
          tooltip: L10().edit,
          onPressed: () {
            widget.model.editForm(
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
      data: widget.model.notes,
    );
  }

}