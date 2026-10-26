import "package:inventree/inventree/model.dart";

/*
 * Class representing a single "audit log" (history) entry.
 *
 * Audit log entries record the change history of a given model instance,
 * and are read-only via the API.
 *
 * Entries are filtered by the server, based on the permissions of the user.
 *
 * Ref: https://github.com/inventree/InvenTree/pull/13069
 * Ref: https://github.com/inventree/InvenTree/pull/13101
 */
class InvenTreeAuditLogEntry extends InvenTreeModel {
  InvenTreeAuditLogEntry() : super();

  InvenTreeAuditLogEntry.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeAuditLogEntry createFromJson(Map<String, dynamic> json) =>
      InvenTreeAuditLogEntry.fromJson(json);

  @override
  String get URL => "audit/";

  // Audit log "action" values
  static const int ACTION_CREATE = 0;
  static const int ACTION_UPDATE = 1;
  static const int ACTION_DELETE = 2;
  static const int ACTION_ACCESS = 3;

  @override
  Map<String, String> defaultFilters() {
    // By default, order by decreasing date, and include field change details
    return {"ordering": "-timestamp", "changes_detail": "true"};
  }

  DateTime? get timestamp => getDate("timestamp");

  String get timestampString => getDateString("timestamp");

  int get action => getInt("action");

  String get actionLabel => getString("action_label");

  // Named event (e.g. a stock adjustment) associated with this entry (if any)
  String get eventLabel => getString("event_label");

  // Title for this entry - the named event, if available
  String get label => eventLabel.isNotEmpty ? eventLabel : actionLabel;

  String get username => getString("actor_username");

  // The model type of the audited instance (e.g. "order.purchaseorder")
  String get modelType => getString("model_type");

  String get modelLabel => getString("model_label");

  String get objectRepr => getString("object_repr");

  // Return a list of the individual field changes recorded against this entry
  List<Map<String, dynamic>> get changes {
    List<Map<String, dynamic>> results = [];

    dynamic detail = jsondata["changes_detail"];

    if (detail is List) {
      for (var row in detail) {
        if (row is Map<String, dynamic>) {
          results.add(row);
        }
      }
    }

    return results;
  }

  // Return a human-readable summary of each field change
  List<String> get changeSummary {
    List<String> lines = [];

    for (var change in changes) {
      String label = (change["label"] ?? change["field"] ?? "").toString();

      if (change["type"] == "m2m") {
        List<dynamic> objects = (change["objects"] ?? []) as List<dynamic>;
        String operation = (change["operation"] ?? "").toString();
        lines.add("${label}: ${operation} ${objects.join(", ")}".trim());
        continue;
      }

      String oldValue = _displayValue(change, "old");
      String newValue = _displayValue(change, "new");

      if (oldValue.isEmpty) {
        lines.add("${label}: ${newValue}");
      } else {
        lines.add("${label}: ${oldValue} → ${newValue}");
      }
    }

    return lines;
  }

  // Return the display value for the "old" or "new" value of a change
  String _displayValue(Map<String, dynamic> change, String key) {
    dynamic value = change["${key}_display"] ?? change[key];

    if (value == null || value.toString() == "None") {
      return "";
    }

    return value.toString();
  }
}
