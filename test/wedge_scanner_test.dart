

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/wedge_controller.dart";
import "package:inventree/helpers.dart";


void main() {
  testWidgets("Wedge Scanner Test", (tester) async {

    await tester.pumpWidget(
      MaterialApp(
        home: WedgeBarcodeController(BarcodeScanHandler())
      )
    );

    // Generate some keyboard data
    await simulateKeyDownEvent(LogicalKeyboardKey.keyA);
    await simulateKeyDownEvent(LogicalKeyboardKey.keyB);
    await simulateKeyDownEvent(LogicalKeyboardKey.keyC);
    await simulateKeyDownEvent(LogicalKeyboardKey.enter);

    // Check debug output
    debugContains("scanned: abc");
    debugContains("No match for barcode");
    debugContains("Server Error");

  });
}