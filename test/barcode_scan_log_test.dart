import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/scan_log.dart";
import "package:inventree/barcode/wedge_controller.dart";
import "package:inventree/helpers.dart";
import "package:inventree/widget/barcode_scan_log.dart";

import "setup.dart";
import "widget/harness.dart";

// Handler with a fixed log context (there is no app context in tests)
class _TestHandler extends BarcodeHandler {
  @override
  String get scanLogContext => "Test context";
}

BarcodeScanLogEntry _entry(
  String barcode, {
  bool success = true,
  int? statusCode = 200,
  dynamic response = const {"success": "Match found"},
}) {
  return BarcodeScanLogEntry(
    timestamp: DateTime(2026, 11, 11, 9, 30),
    context: "Scan stock location",
    barcode: barcode,
    success: success,
    url: "barcode/",
    statusCode: statusCode,
    response: response,
  );
}

void main() {
  setupTestEnv();
  mockSharedPreferences();

  setUp(() {
    BarcodeScanLog().clear();
  });

  group("Scan log store", () {
    test("Entries are newest first", () {
      BarcodeScanLog().add(_entry("first"));
      BarcodeScanLog().add(_entry("second"));

      expect(BarcodeScanLog().entries.map((e) => e.barcode), [
        "second",
        "first",
      ]);
    });

    test("Oldest entries are discarded beyond the limit", () {
      for (int i = 0; i < BarcodeScanLog.maxEntries + 5; i++) {
        BarcodeScanLog().add(_entry("code$i"));
      }

      expect(BarcodeScanLog().length, BarcodeScanLog.maxEntries);
      expect(BarcodeScanLog().entries.first.barcode, "code104");
      expect(BarcodeScanLog().entries.last.barcode, "code5");
    });

    test("Clear empties the log and notifies listeners", () {
      int notified = 0;
      void listener() => notified++;

      BarcodeScanLog().addListener(listener);
      BarcodeScanLog().add(_entry("abc"));
      BarcodeScanLog().clear();
      BarcodeScanLog().removeListener(listener);

      expect(BarcodeScanLog().isEmpty, isTrue);
      expect(notified, 2);
    });

    test("Entries cannot be modified from outside", () {
      BarcodeScanLog().add(_entry("abc"));
      expect(() => BarcodeScanLog().entries.clear(), throwsUnsupportedError);
    });
  });

  group("Scan log entry", () {
    test("Control characters are shown as visible symbols", () {
      expect(visibleControlCharacters("[)>\x1E06\x1DP1\x04"), "[)>␞06␝P1␄");
      expect(visibleControlCharacters("plain"), "plain");
    });

    test("Response is pretty-printed JSON", () {
      final entry = _entry(
        "abc",
        response: {
          "part": {"pk": 1},
        },
      );
      expect(entry.responseText, contains('"pk": 1'));
      expect(entry.responseText, contains("\n"));
    });

    test("Missing response is reported as such", () {
      final entry = _entry("abc", statusCode: null, response: null);
      expect(entry.hasResponse, isFalse);
      expect(entry.responseText, isEmpty);
    });
  });

  group("Scan success rules", () {
    final handler = BarcodeHandler();

    bool check(BarcodeHandler h, int code, Map<String, dynamic> data) =>
        h.isScanSuccessful(APIResponse(statusCode: code, data: data), data);

    test("Default handler", () {
      expect(check(handler, 200, {"success": "Match", "part": {}}), isTrue);
      expect(check(handler, 200, {"action_required": "x"}), isTrue);
      expect(check(handler, 400, {"error": "No match found"}), isFalse);
      expect(check(handler, 200, {"error": "Something"}), isFalse);
      expect(check(handler, -1, {}), isFalse);
    });

    test("Unique (assign) handler treats an unknown barcode as success", () {
      final unique = UniqueBarcodeHandler((_) {});

      expect(
        check(unique, 400, {
          "error": "No match found",
          "barcode_hash": "abc123",
          "barcode_data": "NEWCODE",
        }),
        isTrue,
      );
      expect(check(unique, 200, {"success": "Match"}), isFalse);
    });
  });

  group("Scans are recorded", () {
    test("A failed request is logged with context and barcode", () async {
      await _TestHandler().processBarcode("  LOGME123  ");

      expect(BarcodeScanLog().length, 1);

      final entry = BarcodeScanLog().entries.first;
      expect(entry.barcode, "LOGME123");
      expect(entry.context, "Test context");
      expect(entry.url, "barcode/");
      expect(entry.success, isFalse);
    });

    test("An empty barcode is not logged", () async {
      await _TestHandler().processBarcode("   ");
      expect(BarcodeScanLog().isEmpty, isTrue);
    });
  });

  group("Scan log widgets", () {
    testWidgets("Empty log", (tester) async {
      await pumpScreen(tester, const BarcodeScanLogWidget());

      expect(find.text("No barcodes scanned"), findsOneWidget);
      expect(find.byKey(const Key("barcodeScanLogClear")), findsNothing);
    });

    testWidgets("List, detail and clear", (tester) async {
      BarcodeScanLog().add(
        _entry(
          "LOC\x1D001",
          response: {
            "stocklocation": {"pk": 42},
          },
        ),
      );
      BarcodeScanLog().add(
        _entry(
          "BAD",
          success: false,
          statusCode: 400,
          response: {"error": "No match found"},
        ),
      );

      await pumpScreen(tester, const BarcodeScanLogWidget());

      // Newest first, control characters visible
      expect(find.text("BAD"), findsOneWidget);
      expect(find.text("LOC␝001"), findsOneWidget);

      // Server response is only shown in the detail view
      expect(find.textContaining('"pk": 42'), findsNothing);

      await tester.tap(find.text("LOC␝001"));
      await tester.pumpAndSettle();

      expect(find.text("Success"), findsOneWidget);
      expect(find.text("Scan stock location"), findsOneWidget);
      expect(find.textContaining('"pk": 42'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // A new scan appears in the open list
      BarcodeScanLog().add(_entry("LIVE"));
      await tester.pump();
      expect(find.text("LIVE"), findsOneWidget);

      // Clearing asks for confirmation - cancel keeps the log
      await tester.tap(find.byKey(const Key("barcodeScanLogClear")));
      await tester.pumpAndSettle();

      expect(
        find.text("Remove all entries from the barcode scan log?"),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key("barcodeScanLogClearCancel")));
      await tester.pumpAndSettle();

      expect(BarcodeScanLog().length, 3);
      expect(find.text("LIVE"), findsOneWidget);

      // Confirming clears it
      await tester.tap(find.byKey(const Key("barcodeScanLogClear")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("barcodeScanLogClearConfirm")));
      await tester.pumpAndSettle();

      expect(BarcodeScanLog().isEmpty, isTrue);
      expect(find.text("No barcodes scanned"), findsOneWidget);
    });

    testWidgets("Opened from the scanner, which keeps working after", (
      tester,
    ) async {
      await pumpScreen(tester, WedgeBarcodeController(BarcodeScanHandler()));

      await tester.tap(find.byKey(const Key("barcodeScanLog")));
      // The scanner spinner never settles
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BarcodeScanLogWidget), findsOneWidget);

      await tester.pageBack();
      // The scanner spinner never settles
      await tester.pump(const Duration(seconds: 1));

      // Wedge input is still received after returning
      for (final key in [
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyO,
        LogicalKeyboardKey.keyG,
      ]) {
        await simulateKeyDownEvent(key);
        await simulateKeyUpEvent(key);
      }
      await simulateKeyDownEvent(LogicalKeyboardKey.enter, character: "\n");
      await simulateKeyUpEvent(LogicalKeyboardKey.enter);

      expect(debugContains("scanned: log", raiseAssert: false), isTrue);

      // Let the controller's resume timer complete
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
