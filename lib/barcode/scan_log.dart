import "dart:convert";

import "package:flutter/foundation.dart";

/*
 * A single barcode scan, as recorded in the barcode scan log
 */
class BarcodeScanLogEntry {
  BarcodeScanLogEntry({
    required this.timestamp,
    required this.context,
    required this.barcode,
    required this.success,
    required this.url,
    this.statusCode,
    this.response,
  });

  final DateTime timestamp;

  // Description of what the scan was for (e.g. "Scan stock location")
  final String context;

  // Barcode data, exactly as scanned
  final String barcode;

  // True if the server accepted the barcode
  final bool success;

  // API endpoint the barcode was sent to
  final String url;

  // HTTP status code, or null if no response was received
  final int? statusCode;

  // Decoded response body, or null if no response was received
  final dynamic response;

  bool get hasResponse => statusCode != null && statusCode! >= 0;

  // Server response formatted for display
  String get responseText {
    if (response == null) {
      return "";
    }

    try {
      return const JsonEncoder.withIndent("  ").convert(response);
    } catch (_) {
      return response.toString();
    }
  }

  // Barcode with control characters (e.g. the RS / GS separators in
  // DataMatrix codes) shown as visible Unicode "control pictures"
  String get displayBarcode => visibleControlCharacters(barcode);
}

/*
 * Replace ASCII control characters with their Unicode "control picture"
 * (e.g. 0x1E RS -> U+241E), so they can be seen when displayed
 */
String visibleControlCharacters(String text) {
  final StringBuffer buffer = StringBuffer();

  for (final int c in text.runes) {
    if (c < 0x20) {
      buffer.writeCharCode(0x2400 + c);
    } else if (c == 0x7F) {
      buffer.writeCharCode(0x2421);
    } else {
      buffer.writeCharCode(c);
    }
  }

  return buffer.toString();
}

/*
 * In-memory log of barcode scans.
 *
 * Lives only as long as the app is running (nothing is persisted),
 * and keeps at most [maxEntries] scans, discarding the oldest.
 */
class BarcodeScanLog extends ChangeNotifier {
  factory BarcodeScanLog() => _instance;

  BarcodeScanLog._internal();

  static final BarcodeScanLog _instance = BarcodeScanLog._internal();

  static const int maxEntries = 100;

  final List<BarcodeScanLogEntry> _entries = [];

  // Scans, most recent first
  List<BarcodeScanLogEntry> get entries => List.unmodifiable(_entries.reversed);

  // Most recent scan, or null if the log is empty
  BarcodeScanLogEntry? get latest => _entries.isEmpty ? null : _entries.last;

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  void add(BarcodeScanLogEntry entry) {
    _entries.add(entry);

    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }

    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
