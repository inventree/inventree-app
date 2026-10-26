/*
 * Unit tests for the InvenTreeAuditLogEntry model
 */

import "package:flutter_test/flutter_test.dart";
import "package:inventree/inventree/audit_log.dart";

void main() {
  group("Audit Log:", () {
    test("Label", () async {
      var entry = InvenTreeAuditLogEntry.fromJson({
        "action": 1,
        "action_label": "Update",
        "event_label": null,
      });

      expect(entry.label, equals("Update"));

      entry = InvenTreeAuditLogEntry.fromJson({
        "action": 1,
        "action_label": "Update",
        "event_label": "Stock counted",
      });

      expect(entry.label, equals("Stock counted"));
    });

    test("Change Summary", () async {
      var entry = InvenTreeAuditLogEntry.fromJson({
        "changes_detail": [
          {"field": "quantity", "label": "Quantity", "old": "5", "new": "10"},
          {
            "field": "status",
            "label": "Status",
            "old": 10,
            "new": 50,
            "old_display": "OK",
            "new_display": "Attention",
          },
          {"field": "name", "label": "Name", "old": null, "new": "Widget"},
          {"field": "notes", "label": "Notes", "old": "None", "new": "abc"},
          {
            "field": "tags",
            "label": "Tags",
            "type": "m2m",
            "operation": "add",
            "objects": ["red", "blue"],
          },
        ],
      });

      expect(
        entry.changeSummary,
        equals([
          "Quantity: 5 → 10",
          "Status: OK → Attention",
          "Name: Widget",
          "Notes: abc",
          "Tags: add red, blue",
        ]),
      );
    });

    test("No Changes", () async {
      var entry = InvenTreeAuditLogEntry.fromJson({});

      expect(entry.changes, isEmpty);
      expect(entry.changeSummary, isEmpty);
    });
  });
}
