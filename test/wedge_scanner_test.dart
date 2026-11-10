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
}
