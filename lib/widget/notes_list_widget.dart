import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:flutter_widget_from_html/flutter_widget_from_html.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/notes.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/refreshable_state.dart";

/*
 * A widget for displaying the list of "notes" attached to a given model instance,
 * for servers which support the "multi notes" API.
 *
 * Note content is rendered as HTML, and cannot be edited from within the app.
 *
 * Ref: https://github.com/inventree/InvenTree/pull/11971
 */
class NotesListWidget extends StatefulWidget {
  const NotesListWidget(this.modelType, this.modelId, {Key? key})
    : super(key: key);

  final String modelType;
  final int modelId;

  @override
  _NotesListWidgetState createState() => _NotesListWidgetState();
}

class _NotesListWidgetState extends RefreshableState<NotesListWidget> {
  _NotesListWidgetState();

  List<InvenTreeNoteEntry> notes = [];

  @override
  String getAppBarTitle() => L10().notes;

  @override
  Future<void> request(BuildContext context) async {
    Map<String, String> filters = {
      "model_type": widget.modelType,
      "model_id": widget.modelId.toString(),
    };

    List<InvenTreeNoteEntry> results = [];

    await InvenTreeNoteEntry().list(filters: filters).then((var entries) {
      for (var entry in entries) {
        if (entry is InvenTreeNoteEntry) {
          results.add(entry);
        }
      }
    });

    if (mounted) {
      setState(() {
        notes = results;
      });
    }
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    for (var note in notes) {
      tiles.add(
        ListTile(
          title: Text(note.title.isNotEmpty ? note.title : L10().notes),
          subtitle: note.description.isNotEmpty ? Text(note.description) : null,
          leading: Icon(TablerIcons.note, color: COLOR_ACTION),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NoteViewWidget(note)),
            );
          },
        ),
      );
    }

    if (tiles.isEmpty && !loading) {
      tiles.add(
        ListTile(
          leading: Icon(TablerIcons.note_off, color: COLOR_WARNING),
          title: Text(L10().noNotesFound),
        ),
      );
    }

    return tiles;
  }
}

/*
 * Custom WidgetFactory which authenticates image requests against the
 * InvenTree server, so that (e.g.) note images hosted behind the server's
 * media API can be displayed.
 */
class _NoteWidgetFactory extends WidgetFactory {
  @override
  ImageProvider<Object>? imageProviderFromNetwork(String url) {
    if (url.isEmpty) {
      return null;
    }

    return CachedNetworkImageProvider(
      url,
      headers: InvenTreeAPI().defaultHeaders(),
      cacheManager: InvenTreeAPI().imageCacheManager,
    );
  }
}

/*
 * A read-only widget for viewing the (HTML) content of a single note.
 *
 * Note content is generated server-side by a rich text editor,
 * and cannot be edited from within this app.
 */
class NoteViewWidget extends StatelessWidget {
  const NoteViewWidget(this.note, {Key? key}) : super(key: key);

  final InvenTreeNoteEntry note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title.isNotEmpty ? note.title : L10().notes),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: HtmlWidget(
          note.content,
          baseUrl: Uri.tryParse(InvenTreeAPI().baseUrl),
          factoryBuilder: () => _NoteWidgetFactory(),
        ),
      ),
    );
  }
}

/*
 * Return a ListTile which navigates to the "notes" for the given model instance.
 *
 * If the server supports the "multi notes" API, the user is first presented
 * with a list of available notes to select from.
 *
 * Otherwise, we fall back to the legacy single-notes (markdown) implementation.
 */
ListTile ShowNotesItem(
  BuildContext context,
  InvenTreeModel model,
  String modelType,
) {
  return ListTile(
    title: Text(L10().notes),
    leading: Icon(TablerIcons.note, color: COLOR_ACTION),
    trailing: LinkIcon(),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvenTreeAPI().supportsMultiNotes
              ? NotesListWidget(modelType, model.pk)
              : LegacyNotesWidget(model),
        ),
      );
    },
  );
}
