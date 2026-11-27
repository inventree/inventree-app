/*
 * Unit tests for the camera scan window and barcode selection helpers
 */

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "package:inventree/barcode/scan_selection.dart";

const Size imageSize = Size(1000, 2000);

/// A barcode whose bounding box is centered at [center]
Barcode codeAt(String value, Offset center, {double w = 300, double h = 60}) {
  final Rect r = Rect.fromCenter(center: center, width: w, height: h);
  return Barcode(
    rawValue: value,
    format: BarcodeFormat.code128,
    corners: [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft],
  );
}

void main() {
  group("Scan window", () {
    const Size portrait = Size(400, 700);
    const Size landscape = Size(800, 400);

    test("Square window is centered and sized on the shorter side", () {
      final Rect r = barcodeScanWindow(portrait);

      expect(r.center, const Offset(200, 350));
      expect(r.width, closeTo(320, 0.001));
      expect(r.height, closeTo(320, 0.001));
    });

    test("Linear window is a wide, narrow strip", () {
      final Rect r = barcodeScanWindow(portrait, linear: true);

      expect(r.center, const Offset(200, 350));
      expect(r.width, closeTo(360, 0.001));
      expect(r.height, closeTo(108, 0.001));
      expect(r.width, greaterThan(r.height * 3));
    });

    test("Window fits inside the widget in landscape", () {
      final Rect bounds = Offset.zero & landscape;

      for (final bool linear in [false, true]) {
        final Rect r = barcodeScanWindow(landscape, linear: linear);
        expect(bounds.contains(r.topLeft), isTrue);
        expect(bounds.contains(r.bottomRight), isTrue);
        expect(r.center, const Offset(400, 200));
      }
    });
  });

  group("Barcode selection", () {
    test("No barcodes", () {
      expect(
        selectCenteredBarcode(const BarcodeCapture(size: imageSize)),
        isNull,
      );
    });

    test("Single barcode is always selected", () {
      // Even without position or image size information
      const Barcode code = Barcode(rawValue: "ABC");

      expect(
        selectCenteredBarcode(const BarcodeCapture(barcodes: [code]))?.rawValue,
        "ABC",
      );
    });

    test("Barcode closest to the center is selected", () {
      // Stacked barcodes, as on a distributor label
      final capture = BarcodeCapture(
        size: imageSize,
        barcodes: [
          codeAt("PO", const Offset(500, 800)),
          codeAt("PN", const Offset(500, 1010)),
          codeAt("QTY", const Offset(500, 1200)),
        ],
      );

      expect(selectCenteredBarcode(capture)?.rawValue, "PN");
    });

    test("Order of detection does not matter", () {
      final capture = BarcodeCapture(
        size: imageSize,
        barcodes: [
          codeAt("QTY", const Offset(500, 1200)),
          codeAt("PN", const Offset(480, 990)),
          codeAt("PO", const Offset(500, 800)),
        ],
      );

      expect(selectCenteredBarcode(capture)?.rawValue, "PN");
    });

    test("Ambiguous choice is rejected", () {
      // Two barcodes at (almost) the same distance from the center
      final capture = BarcodeCapture(
        size: imageSize,
        barcodes: [
          codeAt("A", const Offset(500, 900)),
          codeAt("B", const Offset(500, 1105)),
        ],
      );

      expect(selectCenteredBarcode(capture), isNull);
    });

    test("Missing position information is rejected", () {
      final capture = BarcodeCapture(
        size: imageSize,
        barcodes: [
          codeAt("A", const Offset(500, 1000)),
          const Barcode(rawValue: "B"),
        ],
      );

      expect(selectCenteredBarcode(capture), isNull);
    });

    test("Missing image size is rejected", () {
      final capture = BarcodeCapture(
        barcodes: [
          codeAt("A", const Offset(500, 1000)),
          codeAt("B", const Offset(500, 1500)),
        ],
      );

      expect(selectCenteredBarcode(capture), isNull);
    });
  });
}
