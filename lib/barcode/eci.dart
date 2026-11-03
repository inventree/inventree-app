import "dart:convert";
import "dart:typed_data";

/*
 * Interpret an ECI character-set marker reported inside scanned barcode data.
 *
 * A 2D barcode (DataMatrix, QR, Aztec, PDF417) can declare its character set
 * with an ECI designator. Some scanner backends do not apply the declaration;
 * instead they report the ECI number as a single leading byte of the data.
 * ML Kit on Android (used through mobile_scanner) does this: a DataMatrix with
 * ECI 26 (UTF-8) holding "JG-SI1" is reported as 0x1A followed by "JG-SI1",
 * in rawValue, displayValue and the decoded bytes alike.
 *
 * When the decoded bytes begin with a known ECI number, and the reported
 * string begins with the same character (showing the marker leaked into the
 * value), the rest of the bytes are decoded with the declared character set.
 * In every other case the reported string is returned unchanged.
 */

/// ECI assignments understood here: ECI number -> character set.
const Map<int, Encoding> eciCharsets = {
  3: latin1, // ISO-8859-1
  26: utf8, // UTF-8
  27: ascii, // US-ASCII
};

String decodeEciPrefixed(String? value, Uint8List? bytes) {
  final String reported = value ?? "";

  if (bytes == null || bytes.length < 2 || reported.isEmpty) {
    return reported;
  }

  final int marker = bytes.first;
  final Encoding? charset = eciCharsets[marker];

  if (charset == null || reported.codeUnitAt(0) != marker) {
    return reported;
  }

  try {
    return charset.decode(bytes.sublist(1));
  } on FormatException {
    return reported;
  }
}
