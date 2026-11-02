/*
 * Unit tests for interpreting ECI markers in scanned barcode data
 */

import "dart:convert";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";

import "package:inventree/barcode/eci.dart";

/// Bytes as the scanner reports them: ECI number, then the encoded data.
Uint8List withMarker(int eci, List<int> data) =>
    Uint8List.fromList([eci, ...data]);

void main() {
  group("ECI marker in scanned data", () {
    test("UTF-8 marker (ECI 26) is removed", () {
      final bytes = withMarker(26, ascii.encode("INV-SI1"));
      final reported = String.fromCharCodes(bytes);

      expect(decodeEciPrefixed(reported, bytes), "INV-SI1");
    });

    test("UTF-8 data is decoded with the declared character set", () {
      final bytes = withMarker(26, utf8.encode("Crème brûlée"));
      final reported = String.fromCharCodes(bytes);

      expect(decodeEciPrefixed(reported, bytes), "Crème brûlée");
    });

    test("ISO-8859-1 marker (ECI 3) is decoded as Latin-1", () {
      final bytes = withMarker(3, latin1.encode("Crème"));
      final reported = String.fromCharCodes(bytes);

      expect(decodeEciPrefixed(reported, bytes), "Crème");
    });

    test("Data without a marker is unchanged", () {
      final bytes = Uint8List.fromList(ascii.encode("INV-SI1"));

      expect(decodeEciPrefixed("INV-SI1", bytes), "INV-SI1");
    });

    test("Unknown leading control byte is left alone", () {
      // 0x1D (GS) is used by GS1 codes and is not an ECI marker here
      final bytes = withMarker(0x1D, ascii.encode("01234"));
      final reported = String.fromCharCodes(bytes);

      expect(decodeEciPrefixed(reported, bytes), reported);
    });

    test("Marker in bytes but not in the string is left alone", () {
      final bytes = withMarker(26, ascii.encode("INV-SI1"));

      expect(decodeEciPrefixed("INV-SI1", bytes), "INV-SI1");
    });

    test("Invalid UTF-8 falls back to the reported string", () {
      final bytes = withMarker(26, [0xFF, 0xFE]);
      final reported = String.fromCharCodes(bytes);

      expect(decodeEciPrefixed(reported, bytes), reported);
    });

    test("Missing bytes fall back to the reported string", () {
      expect(decodeEciPrefixed("INV-SI1", null), "INV-SI1");
      expect(decodeEciPrefixed(null, null), "");
    });
  });
}
