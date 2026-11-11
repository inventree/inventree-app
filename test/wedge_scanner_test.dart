import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/wedge_controller.dart";
import "package:inventree/helpers.dart";

// ASCII separators used by ISO/IEC 15434 (e.g. DigiKey / Mouser DataMatrix)
const String RS = "\x1E";
const String GS = "\x1D";
const String EOT = "\x04";

/*
 * Build a key-down event exactly as Flutter delivers it on Android
 * for a Ctrl+<key> combination: getUnicodeChar() returns 0, so character is null
 */
KeyDownEvent androidCtrlKeyDown(LogicalKeyboardKey key) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    character: null,
    timeStamp: Duration.zero,
  );
}

Future<void> typeCtrl(LogicalKeyboardKey key, {bool shift = false}) async {
  await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await simulateKeyDownEvent(key);
  await simulateKeyUpEvent(key);
  if (shift) await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> typeText(String text) async {
  for (final String c in text.split("")) {
    // Shifted symbols are sent on their physical (unshifted) key
    const Map<String, LogicalKeyboardKey> symbols = {
      "\n": LogicalKeyboardKey.enter,
      "[": LogicalKeyboardKey.bracketLeft,
      ")": LogicalKeyboardKey.digit0,
      ">": LogicalKeyboardKey.period,
    };
    final LogicalKeyboardKey key =
        symbols[c] ?? LogicalKeyboardKey.findKeyByKeyId(c.codeUnitAt(0))!;
    await simulateKeyDownEvent(key, character: c);
    await simulateKeyUpEvent(key);
  }
}

void main() {
  testWidgets("Wedge Scanner Test", (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WedgeBarcodeController(BarcodeScanHandler())),
    );

    // Generate some keyboard data
    await simulateKeyDownEvent(LogicalKeyboardKey.keyA);
    await simulateKeyDownEvent(LogicalKeyboardKey.keyB);
    await simulateKeyDownEvent(LogicalKeyboardKey.keyC);
    await simulateKeyDownEvent(LogicalKeyboardKey.enter, character: "\n");

    // Check debug output
    debugContains("scanned: abc");
    debugContains("Scanned barcode data: 'abc'");

    // No server is available, so the API layer reports the failure,
    // and the handler exits early (rather than treating it as an unknown barcode)
    debugContains("showServerError");
    expect(debugContains("No match for barcode", raiseAssert: false), isFalse);
  });

  group("Wedge control characters (#542)", () {
    test("Ctrl combos with null character map to separators", () {
      // This is the Android case which previously dropped the character
      expect(
        wedgeCharacterForEvent(
          androidCtrlKeyDown(LogicalKeyboardKey.bracketRight),
          ctrlPressed: true,
        ),
        GS,
      );
      expect(
        wedgeCharacterForEvent(
          androidCtrlKeyDown(LogicalKeyboardKey.digit6),
          ctrlPressed: true,
        ),
        RS,
      );
      expect(
        wedgeCharacterForEvent(
          androidCtrlKeyDown(LogicalKeyboardKey.caret),
          ctrlPressed: true,
        ),
        RS,
      );
      expect(
        wedgeCharacterForEvent(
          androidCtrlKeyDown(LogicalKeyboardKey.keyD),
          ctrlPressed: true,
        ),
        EOT,
      );
    });

    test("Platform-supplied control characters are preserved", () {
      // Desktop / iOS may already report the control character itself
      for (final String c in [RS, GS, EOT]) {
        final event = KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          character: c,
          timeStamp: Duration.zero,
        );
        expect(wedgeCharacterForEvent(event, ctrlPressed: false), c);
      }
    });

    test("Normal characters and bare modifiers are unchanged", () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        character: "a",
        timeStamp: Duration.zero,
      );
      expect(wedgeCharacterForEvent(event, ctrlPressed: false), "a");

      // Without Ctrl, a null character is still ignored
      expect(
        wedgeCharacterForEvent(
          androidCtrlKeyDown(LogicalKeyboardKey.bracketRight),
          ctrlPressed: false,
        ),
        isNull,
      );

      // The Ctrl key itself produces nothing
      expect(
        wedgeCharacterForEvent(
          androidCtrlKeyDown(LogicalKeyboardKey.controlLeft),
          ctrlPressed: true,
        ),
        isNull,
      );
    });

    testWidgets("ISO 15434 DataMatrix scan keeps RS / GS / EOT", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: WedgeBarcodeController(BarcodeScanHandler())),
      );

      // [)>{RS}06{GS}pABC{RS}{EOT}  (structure of a DigiKey label)
      await typeText("[)>");
      await typeCtrl(LogicalKeyboardKey.digit6, shift: true); // RS
      await typeText("06");
      await typeCtrl(LogicalKeyboardKey.bracketRight); // GS
      await typeText("pabc");
      await typeCtrl(LogicalKeyboardKey.digit6, shift: true); // RS
      await typeCtrl(LogicalKeyboardKey.keyD); // EOT
      await simulateKeyDownEvent(LogicalKeyboardKey.enter, character: "\n");

      expect(
        debugContains(
          "scanned: [)>${RS}06${GS}pabc$RS$EOT",
          raiseAssert: false,
        ),
        isTrue,
      );
    });
  });

  group("Wedge multi-barcode blanking (#625)", () {
    final DateTime t0 = DateTime(2026);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    // Feed a string one character every [gapMs], starting at [startMs].
    // Returns every completed barcode.
    List<String> feed(
      WedgeScanBuffer buffer,
      String text, {
      int startMs = 0,
      int gapMs = 10,
      bool accepting = true,
    }) {
      final List<String> results = [];
      int ms = startMs;
      for (final String c in text.split("")) {
        final String? result = buffer.addCharacter(
          c,
          at(ms),
          accepting: accepting,
        );
        if (result != null) results.add(result);
        ms += gapMs;
      }
      return results;
    }

    test("Only the first barcode in a multi-barcode burst is returned", () {
      final buffer = WedgeScanBuffer();
      expect(feed(buffer, "first\nsecond\nthird\n"), ["first"]);
    });

    test("Long trailing barcodes are never resumed part-way", () {
      // The trailing burst (300 chars @ 10ms = 3s) far outlasts the
      // blanking period, but keeps extending it, so no fragment leaks out
      final buffer = WedgeScanBuffer();
      final String trailing = "${"x" * 150}\n${"y" * 150}\n";
      expect(feed(buffer, "first\n$trailing"), ["first"]);
    });

    test("A new scan after the quiet period is accepted", () {
      final buffer = WedgeScanBuffer();
      expect(feed(buffer, "first\nsecond\n"), ["first"]);

      // Last key at 120ms; blanking ends at 620ms
      expect(feed(buffer, "early\n", startMs: 400), isEmpty);
      expect(feed(buffer, "next\n", startMs: 1200), ["next"]);
    });

    test("Input while paused is discarded and blanks its continuation", () {
      final buffer = WedgeScanBuffer();

      // Scanner paused part-way through a barcode, then resumed
      expect(feed(buffer, "abcdef", accepting: false), isEmpty);
      expect(feed(buffer, "ghij\n", startMs: 60), isEmpty);

      expect(feed(buffer, "fresh\n", startMs: 1000), ["fresh"]);
    });

    test("Characters within a barcode still time out", () {
      final buffer = WedgeScanBuffer();
      expect(feed(buffer, "stale"), isEmpty);
      expect(feed(buffer, "new\n", startMs: 1000), ["new"]);
    });

    test("Empty lines do not start blanking", () {
      final buffer = WedgeScanBuffer();
      expect(feed(buffer, "\n\nabc\n"), ["abc"]);
    });

    testWidgets("Controller submits only the first of several barcodes", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: WedgeBarcodeController(BarcodeScanHandler())),
      );

      await typeText("multia\n");
      await typeText("multib\n");

      expect(debugContains("scanned: multia", raiseAssert: false), isTrue);
      expect(debugContains("multib", raiseAssert: false), isFalse);

      // Let the controller's resume timer complete
      await tester.pump(const Duration(seconds: 1));
    });

    group("Scans without a terminating newline", () {
      test("Flush returns the buffered barcode", () {
        final buffer = WedgeScanBuffer();
        expect(feed(buffer, "noenter"), isEmpty);
        expect(buffer.hasPendingCharacters, isTrue);
        expect(buffer.flush(at(400)), "noenter");
        expect(buffer.hasPendingCharacters, isFalse);

        // Nothing left to flush
        expect(buffer.flush(at(500)), isNull);
      });

      test("Flushed barcode starts the blanking period", () {
        final buffer = WedgeScanBuffer();
        feed(buffer, "first");
        expect(buffer.flush(at(300)), "first");

        // Trailing input is discarded, and keeps the window open
        expect(feed(buffer, "second\n", startMs: 400), isEmpty);
        expect(buffer.flush(at(600)), isNull);

        expect(feed(buffer, "third\n", startMs: 1500), ["third"]);
      });

      test("Short input is discarded rather than submitted", () {
        final buffer = WedgeScanBuffer();
        feed(buffer, "abc");
        expect(buffer.flush(at(300)), isNull);
        expect(buffer.hasPendingCharacters, isFalse);

        // ...and does not start the blanking period
        expect(feed(buffer, "next\n", startMs: 310), ["next"]);
      });

      testWidgets("Controller submits after the character timeout", (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(home: WedgeBarcodeController(BarcodeScanHandler())),
        );

        await typeText("timeoutscan");
        expect(debugContains("timeoutscan", raiseAssert: false), isFalse);

        await tester.pump(const Duration(milliseconds: 300));
        expect(
          debugContains("scanned: timeoutscan", raiseAssert: false),
          isTrue,
        );

        // Let the controller's resume timer complete
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets("Controller ignores a short stray key press", (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: WedgeBarcodeController(BarcodeScanHandler())),
        );

        await typeText("qz");
        await tester.pump(const Duration(milliseconds: 300));
        expect(debugContains("scanned: qz", raiseAssert: false), isFalse);
      });
    });
  });
}
