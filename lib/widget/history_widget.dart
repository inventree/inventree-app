import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/inventree/audit_log.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/l10.dart";

import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";

/*
 * A read-only widget for displaying the history (audit log)
 * for a given model instance.
 *
 * Ref: https://github.com/inventree/InvenTree/pull/13069
 */
class HistoryWidget extends StatefulWidget {
  const HistoryWidget(this.modelType, this.modelId, {Key? key})
    : super(key: key);

  final String modelType;
  final int modelId;

  @override
  _HistoryWidgetState createState() => _HistoryWidgetState();
}

class _HistoryWidgetState extends RefreshableState<HistoryWidget> {
  _HistoryWidgetState();

  @override
  String getAppBarTitle() => L10().history;

  @override
  Widget getBody(BuildContext context) {
    Map<String, String> filters = {
      "model_type": widget.modelType,
      "model_id": widget.modelId.toString(),
    };

    return PaginatedHistoryList(widget.modelType, filters);
  }
}

/*
 * Widget which displays a paginated list of history entries
 */
class PaginatedHistoryList extends PaginatedSearchWidget {
  const PaginatedHistoryList(this.modelType, Map<String, String> filters)
    : super(filters: filters);

  final String modelType;

  @override
  String get searchTitle => L10().history;

  @override
  _PaginatedHistoryState createState() => _PaginatedHistoryState();
}

/*
 * State class for the paginated history list
 */
class _PaginatedHistoryState
    extends PaginatedSearchState<PaginatedHistoryList> {
  _PaginatedHistoryState() : super();

  @override
  String get prefix => "history_";

  @override
  Map<String, String> get orderingOptions => {};

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {};

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeAuditLogEntry().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  IconData _actionIcon(InvenTreeAuditLogEntry entry) {
    switch (entry.action) {
      case InvenTreeAuditLogEntry.ACTION_CREATE:
        return TablerIcons.circle_plus;
      case InvenTreeAuditLogEntry.ACTION_DELETE:
        return TablerIcons.trash;
      default:
        return TablerIcons.edit;
    }
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeAuditLogEntry entry = model as InvenTreeAuditLogEntry;

    List<String> lines = [];

    // Entries may also be provided for "child" objects (e.g. line items)
    if (entry.modelType.split(".").last != widget.modelType) {
      lines.add("${entry.modelLabel}: ${entry.objectRepr}");
    }

    if (entry.notes.isNotEmpty) {
      lines.add(entry.notes);
    }

    lines.addAll(entry.changeSummary);

    return ListTile(
      leading: Icon(_actionIcon(entry)),
      title: Text(entry.label),
      subtitle: lines.isNotEmpty ? Text(lines.join("\n")) : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(entry.timestampString),
          if (entry.username.isNotEmpty) Text(entry.username),
        ],
      ),
    );
  }
}

/*
 * Return a ListTile which navigates to the history for the given model instance
 */
ListTile ShowHistoryItem(BuildContext context, String modelType, int modelId) {
  return ListTile(
    title: Text(L10().history),
    leading: Icon(TablerIcons.history, color: COLOR_ACTION),
    trailing: LinkIcon(),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryWidget(modelType, modelId),
        ),
      );
    },
  );
}
