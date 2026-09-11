import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:flutter_markdown/flutter_markdown.dart";
import "package:inventree/l10.dart";

/*
 * A widget for displaying the single (markdown) notes field associated with
 * a given model, for servers which do not support the "multi notes" API.
 * We need to pass in the following parameters:
 *
 * - Model instance
 * - Title for the app bar
 */
class LegacyNotesWidget extends StatefulWidget {
  const LegacyNotesWidget(this.model, {Key? key}) : super(key: key);

  final InvenTreeModel model;

  @override
  _LegacyNotesState createState() => _LegacyNotesState();
}

/*
 * Class representing the state of the LegacyNotesWidget
 */
class _LegacyNotesState extends RefreshableState<LegacyNotesWidget> {
  _LegacyNotesState();

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
          icon: Icon(TablerIcons.edit),
          tooltip: L10().edit,
          onPressed: () {
            widget.model.editForm(
              context,
              L10().editNotes,
              fields: {
                "notes": {"multiline": true},
              },
              onSuccess: (data) async {
                refresh(context);
              },
            );
          },
        ),
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return Markdown(selectable: false, data: widget.model.notes);
  }
}
