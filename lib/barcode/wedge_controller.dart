import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/handler.dart";

import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";

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

  List<String> _scannedCharacters = [];

  DateTime? _lastScanTime;

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
    if (!scanning) {
      return;
    }

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

    DateTime now = DateTime.now();

    // Throw away old characters
    if (_lastScanTime == null ||
        _lastScanTime!.isBefore(now.subtract(Duration(milliseconds: 250)))) {
      _scannedCharacters.clear();
    }

    _lastScanTime = now;

    if (character == "\n") {
      if (_scannedCharacters.isNotEmpty) {
        // Debug output required for unit testing
        debug("scanned: ${_scannedCharacters.join()}");
        handleBarcodeData(_scannedCharacters.join());
      }

      _scannedCharacters.clear();
    } else {
      _scannedCharacters.add(character);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10().scanBarcode)),
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
