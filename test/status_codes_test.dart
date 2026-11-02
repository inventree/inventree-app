/*
 * Unit tests for the InvenTreeStatusCode class
 *
 * Status code data is provided directly, rather than loaded from the server
 */

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/status_codes.dart";
import "package:one_context/one_context.dart";

InvenTreeStatusCode buildStatusCodes() {
  final codes = InvenTreeStatusCode("stock/status/");

  codes.data = {
    "OK": {"key": 10, "name": "OK", "label": "OK", "color": "success"},
    "ATTENTION": {
      "key": 50,
      "name": "ATTENTION",
      "label": "Attention needed",
      "color": "WARNING",
    },
    "DAMAGED": {"key": 55, "name": "DAMAGED", "label": "Damaged"},
    "DESTROYED": {
      "key": 60,
      "name": "DESTROYED",
      "label": "Destroyed",
      "color": "danger",
    },
    // Malformed entries should be ignored
    "INVALID": "not a map",
    "STRING_KEY": {"key": "70", "name": "STRING_KEY", "label": "String"},
  };

  return codes;
}

void main() {
  group("Status Codes:", () {
    test("Choices", () async {
      final codes = buildStatusCodes();

      expect(
        codes.choices,
        equals([
          {"value": 10, "display_name": "OK"},
          {"value": 50, "display_name": "Attention needed"},
          {"value": 55, "display_name": "Damaged"},
          {"value": 60, "display_name": "Destroyed"},
          {"value": "70", "display_name": "String"},
        ]),
      );

      expect(InvenTreeStatusCode("x/").choices, isEmpty);
    });

    test("Entry", () async {
      final codes = buildStatusCodes();

      expect(codes.entry(50)["name"], equals("ATTENTION"));
      expect(codes.entry(999), isEmpty);

      // Only integer keys are matched
      expect(codes.entry(70), isEmpty);
    });

    test("Label", () async {
      final codes = buildStatusCodes();

      expect(codes.label(10), equals("OK"));
      expect(codes.label(50), equals("Attention needed"));

      // Unknown status returns the code itself
      expect(codes.label(999), equals("999"));
    });

    test("Name", () async {
      final codes = buildStatusCodes();

      expect(codes.name(60), equals("DESTROYED"));
      expect(codes.name(999), equals(""));

      expect(codes.isNameIn(10, ["OK", "DAMAGED"]), isTrue);
      expect(codes.isNameIn(60, ["OK", "DAMAGED"]), isFalse);
      expect(codes.isNameIn(999, ["OK"]), isFalse);
    });

    // Theme-dependent colors require an app context
    testWidgets("Color", (tester) async {
      OneContext().key = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          builder: OneContext().builder,
          navigatorKey: OneContext().key,
          home: const SizedBox(),
        ),
      );

      final codes = buildStatusCodes();

      expect(codes.color(10), equals(COLOR_SUCCESS));
      expect(codes.color(50), equals(COLOR_WARNING));
      expect(codes.color(60), equals(COLOR_DANGER));

      // Missing color, or unknown status
      expect(codes.color(55), equals(COLOR_GRAY_LIGHT));
      expect(codes.color(999), equals(COLOR_GRAY_LIGHT));

      final Map<String, Color> colors = {
        "primary": COLOR_PROGRESS,
        "secondary": COLOR_GRAY_LIGHT,
        "dark": COLOR_TEXT,
        "info": COLOR_PROGRESS,
        "unknown": COLOR_GRAY_LIGHT,
      };

      colors.forEach((name, color) {
        codes.data = {
          "X": {"key": 1, "name": "X", "label": "X", "color": name},
        };

        expect(codes.color(1), equals(color), reason: name);
      });
    });
  });
}
