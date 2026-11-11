import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:intl/intl.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/scan_log.dart";
import "package:inventree/l10.dart";

const TextStyle _monospace = TextStyle(fontFamily: "monospace", fontSize: 12);

String _formatTimestamp(DateTime timestamp) =>
    DateFormat("yyyy-MM-dd HH:mm:ss").format(timestamp);

Widget _statusIcon(BarcodeScanLogEntry entry) => entry.success
    ? Icon(TablerIcons.circle_check, color: COLOR_SUCCESS)
    : Icon(TablerIcons.circle_x, color: COLOR_DANGER);

/*
 * Displays the barcode scan log (most recent scan first)
 */
class BarcodeScanLogWidget extends StatelessWidget {
  const BarcodeScanLogWidget({super.key});

  // Ask the user to confirm before clearing the scan log
  Future<void> _confirmClear(BuildContext context, BarcodeScanLog log) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: ListTile(
          leading: Icon(TablerIcons.trash, color: COLOR_DANGER),
          title: Text(
            L10().barcodeScanLogClear,
            style: TextStyle(color: COLOR_DANGER),
          ),
        ),
        content: Text(L10().barcodeScanLogClearDetail),
        actions: [
          TextButton(
            key: const Key("barcodeScanLogClearCancel"),
            child: Text(L10().cancel),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            key: const Key("barcodeScanLogClearConfirm"),
            child: Text(L10().delete),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      log.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final BarcodeScanLog log = BarcodeScanLog();

    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final List<BarcodeScanLogEntry> entries = log.entries;

        return Scaffold(
          appBar: AppBar(
            title: Text(L10().barcodeScanLog),
            actions: [
              if (entries.isNotEmpty)
                IconButton(
                  key: const Key("barcodeScanLogClear"),
                  icon: const Icon(TablerIcons.trash),
                  tooltip: L10().barcodeScanLogClear,
                  onPressed: () => _confirmClear(context, log),
                ),
            ],
          ),
          body: entries.isEmpty
              ? Center(child: Text(L10().barcodeScanLogEmpty))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final BarcodeScanLogEntry entry = entries[index];

                    return ListTile(
                      leading: _statusIcon(entry),
                      title: Text(
                        entry.displayBarcode,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _monospace,
                      ),
                      subtitle: Text(
                        [
                          if (entry.context.isNotEmpty) entry.context,
                          _formatTimestamp(entry.timestamp),
                        ].join("\n"),
                      ),
                      trailing: const Icon(TablerIcons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BarcodeScanLogDetailWidget(entry: entry),
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

/*
 * Full detail for a single barcode scan, including the server response
 */
class BarcodeScanLogDetailWidget extends StatelessWidget {
  const BarcodeScanLogDetailWidget({required this.entry, super.key});

  final BarcodeScanLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final String status = entry.success
        ? L10().barcodeScanSuccess
        : L10().barcodeScanFailed;

    return Scaffold(
      appBar: AppBar(title: Text(L10().barcodeScanLog)),
      body: ListView(
        children: [
          ListTile(
            leading: _statusIcon(entry),
            title: Text(status),
            subtitle: Text(
              [
                if (entry.hasResponse)
                  "${L10().statusCode}: ${entry.statusCode}",
                entry.url,
                _formatTimestamp(entry.timestamp),
              ].join("\n"),
            ),
          ),
          if (entry.context.isNotEmpty)
            ListTile(
              title: Text(L10().barcodeScanContext),
              subtitle: Text(entry.context),
            ),
          ListTile(
            title: Text(L10().barcodeScanData),
            subtitle: SelectableText(entry.displayBarcode, style: _monospace),
          ),
          ListTile(
            title: Text(L10().barcodeScanResponse),
            subtitle: entry.response == null
                ? Text(L10().barcodeScanNoResponse)
                : SelectableText(entry.responseText, style: _monospace),
          ),
        ],
      ),
    );
  }
}
