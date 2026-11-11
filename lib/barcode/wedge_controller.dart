import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/handler.dart";

import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";
import "package:inventree/preferences.dart";

/*
 * Control characters produced by Ctrl+<key>, keyed by logical key.
 *
 * Keyboard-wedge scanners have no HID keycode for ASCII control characters,
 * so they type them as Ctrl combinations (e.g. GS = Ctrl+], RS = Ctrl+^).
 * On Android, KeyEvent.getUnicodeChar() returns 0 for any Ctrl combination,
 * so Flutter reports KeyEvent.character == null and the character is lost
 * unless we rebuild it here.
 */
final Map<LogicalKeyboardKey, String> _ctrlCharacters = {
  // Ctrl+@ / Ctrl+2 -> NUL is deliberately omitted (a NUL would truncate data)
  LogicalKeyboardKey.keyA: "\x01",
  LogicalKeyboardKey.keyB: "\x02",
  LogicalKeyboardKey.keyC: "\x03",
  LogicalKeyboardKey.keyD: "\x04", // EOT
  LogicalKeyboardKey.keyE: "\x05",
  LogicalKeyboardKey.keyF: "\x06",
  LogicalKeyboardKey.keyG: "\x07",
  LogicalKeyboardKey.keyH: "\x08",
  LogicalKeyboardKey.keyI: "\x09",
  LogicalKeyboardKey.keyJ: "\x0A",
  LogicalKeyboardKey.keyK: "\x0B",
  LogicalKeyboardKey.keyL: "\x0C",
  LogicalKeyboardKey.keyM: "\x0D",
  LogicalKeyboardKey.keyN: "\x0E",
  LogicalKeyboardKey.keyO: "\x0F",
  LogicalKeyboardKey.keyP: "\x10",
  LogicalKeyboardKey.keyQ: "\x11",
  LogicalKeyboardKey.keyR: "\x12",
  LogicalKeyboardKey.keyS: "\x13",
  LogicalKeyboardKey.keyT: "\x14",
  LogicalKeyboardKey.keyU: "\x15",
  LogicalKeyboardKey.keyV: "\x16",
  LogicalKeyboardKey.keyW: "\x17",
  LogicalKeyboardKey.keyX: "\x18",
  LogicalKeyboardKey.keyY: "\x19",
  LogicalKeyboardKey.keyZ: "\x1A",
  LogicalKeyboardKey.bracketLeft: "\x1B", // ESC
  LogicalKeyboardKey.backslash: "\x1C", // FS
  LogicalKeyboardKey.bracketRight: "\x1D", // GS
  LogicalKeyboardKey.caret: "\x1E", // RS
  LogicalKeyboardKey.digit6: "\x1E", // RS (Ctrl+Shift+6 on US layout)
  LogicalKeyboardKey.underscore: "\x1F", // US
  LogicalKeyboardKey.minus: "\x1F", // US (Ctrl+Shift+- on US layout)
};

/*
 * Resolve the character a wedge scanner meant to send for a key-down event.
 *
 * Returns null when the event produces no character (e.g. a bare modifier).
 */
String? wedgeCharacterForEvent(KeyEvent event, {required bool ctrlPressed}) {
  if (ctrlPressed) {
    final String? ctrlChar = _ctrlCharacters[event.logicalKey];
    if (ctrlChar != null) {
      return ctrlChar;
    }
  }

  final String? character = event.character;

  if (character == null || character.isEmpty) {
    return null;
  }

  return character;
}

/*
 * Assembles keyboard-wedge characters into complete barcodes.
 *
 * A wedge scanner can read several barcodes in one shot (e.g. an InvenTree
 * label next to a DigiKey label) and types them all, separated by newlines.
 * Only the first barcode is wanted (#625), so after a barcode is completed
 * all further input is discarded until the keyboard has been quiet for
 * [blankingPeriod]. The window is extended by every discarded key, so a long
 * trailing barcode cannot be resumed part-way through and submitted as a
 * fragment.
 *
 * Input received while the scanner is paused (processing a barcode) is
 * treated the same way.
 */
class WedgeScanBuffer {
  WedgeScanBuffer({
    this.blankingPeriod = const Duration(milliseconds: 500),
    this.characterTimeout = const Duration(milliseconds: 250),
    this.minimumFlushLength = 4,
  });

  // Quiet time required after a completed scan before accepting new input
  Duration blankingPeriod;

  // Maximum gap between characters of a single barcode.
  // Also the time after the last character at which a scan with no
  // terminating newline is submitted (see [flush])
  final Duration characterTimeout;

  // Shortest unterminated input which [flush] will submit, so that stray
  // key presses on a hardware keyboard do not trigger barcode lookups
  final int minimumFlushLength;

  bool get hasPendingCharacters => _characters.isNotEmpty;

  final List<String> _characters = [];

  DateTime? _lastKeyTime;

  DateTime? _blankUntil;

  bool isBlanking(DateTime now) =>
      _blankUntil != null && now.isBefore(_blankUntil!);

  /*
   * Add a single character received at [now].
   * Returns the completed barcode when a newline terminates one, else null.
   * Set [accepting] to false while the scanner is paused.
   */
  String? addCharacter(
    String character,
    DateTime now, {
    bool accepting = true,
  }) {
    if (!accepting || isBlanking(now)) {
      _blankUntil = now.add(blankingPeriod);
      _characters.clear();
      _lastKeyTime = now;
      return null;
    }

    // Throw away stale characters from an earlier, incomplete scan
    if (_lastKeyTime == null ||
        now.difference(_lastKeyTime!) > characterTimeout) {
      _characters.clear();
    }

    _lastKeyTime = now;

    if (character != "\n") {
      _characters.add(character);
      return null;
    }

    final String data = _characters.join();
    _characters.clear();

    if (data.isEmpty) {
      return null;
    }

    _blankUntil = now.add(blankingPeriod);
    return data;
  }

  /*
   * Complete a scan which was not terminated by a newline.
   *
   * Call once [characterTimeout] has passed since the last character.
   * Returns the buffered barcode, or null if there is none (or it is shorter
   * than [minimumFlushLength], in which case it is discarded).
   * A returned barcode starts the blanking period, as for a newline.
   */
  String? flush(DateTime now) {
    final String data = _characters.join();
    _characters.clear();

    if (data.length < minimumFlushLength) {
      return null;
    }

    _blankUntil = now.add(blankingPeriod);
    return data;
  }
}

/*
 * Barcode controller which acts as a keyboard wedge,
 * intercepting barcode data which is entered as rapid keyboard presses
 */
class WedgeBarcodeController extends InvenTreeBarcodeController {
  const WedgeBarcodeController(BarcodeHandler handler, {Key? key})
    : super(handler, key: key);

  @override
  State<StatefulWidget> createState() => _WedgeBarcodeControllerState();
}

class _WedgeBarcodeControllerState extends InvenTreeBarcodeControllerState {
  _WedgeBarcodeControllerState() : super();

  bool canScan = true;

  bool get scanning => mounted && canScan;

  final FocusNode _focusNode = FocusNode();

  final WedgeScanBuffer _buffer = WedgeScanBuffer();

  // Submits a scan which is not terminated by a newline
  Timer? _flushTimer;

  @override
  void initState() {
    super.initState();
    _loadScanDelay();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitBarcode(String barcode) {
    // Debug output required for unit testing
    debug("scanned: ${barcode}");
    handleBarcodeData(barcode);
  }

  void _flushPendingScan() {
    _flushTimer = null;

    final String? barcode = _buffer.flush(DateTime.now());

    if (barcode != null && scanning) {
      _submitBarcode(barcode);
    }
  }

  // Blank further input for the user's scan delay (never shorter than the
  // inter-character timeout, so trailing barcodes are always discarded)
  Future<void> _loadScanDelay() async {
    final int delay =
        await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_DELAY, 500)
            as int;

    final Duration period = Duration(milliseconds: delay);

    _buffer.blankingPeriod = period > _buffer.characterTimeout
        ? period
        : _buffer.characterTimeout;
  }

  @override
  bool get isScanPaused => !canScan;

  @override
  Future<void> pauseScan() async {
    if (mounted) {
      setState(() {
        canScan = false;
      });
    }
  }

  @override
  Future<void> resumeScan() async {
    if (mounted) {
      setState(() {
        canScan = true;
      });
    }
  }

  // Callback for a single key press / scan
  void handleKeyEvent(KeyEvent event) {
    // Look only for key-down events
    if (event is! KeyDownEvent) {
      return;
    }

    // Ignore events without a character code
    // (control characters are rebuilt from Ctrl+<key> combinations)
    final String? character = wedgeCharacterForEvent(
      event,
      ctrlPressed: HardwareKeyboard.instance.isControlPressed,
    );

    if (character == null) {
      return;
    }

    // Input is still tracked while paused, so that the blanking window
    // covers barcodes which are typed while the previous one is processed
    final String? barcode = _buffer.addCharacter(
      character,
      DateTime.now(),
      accepting: scanning,
    );

    // Restart the timeout for scanners which send no terminating newline
    _flushTimer?.cancel();
    _flushTimer = _buffer.hasPendingCharacters
        ? Timer(_buffer.characterTimeout, _flushPendingScan)
        : null;

    if (barcode != null) {
      _submitBarcode(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().scanBarcode),
        actions: [buildScanLogAction()],
      ),
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(flex: 5),
            Icon(TablerIcons.barcode, size: 64),
            Spacer(flex: 5),
            KeyboardListener(
              autofocus: true,
              focusNode: _focusNode,
              child: SizedBox(
                child: CircularProgressIndicator(
                  color: scanning ? COLOR_ACTION : COLOR_PROGRESS,
                ),
                width: 64,
                height: 64,
              ),
              onKeyEvent: (event) {
                handleKeyEvent(event);
              },
              // onBarcodeScanned: (String barcode) {
              //   debug("scanned: ${barcode}");
              //   if (scanning) {
              //     // Process the barcode data
              //     handleBarcodeData(barcode);
              //   }
              // },
            ),
            Spacer(flex: 5),
            Padding(
              child: Text(
                widget.handler.getOverlayText(context),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              padding: EdgeInsets.all(20),
            ),
          ],
        ),
      ),
    );
  }
}
