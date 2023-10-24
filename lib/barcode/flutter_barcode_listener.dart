
/*
 * Custom keyboard listener which allows the app to act as a keyboard "wedge",
 * and intercept barcodes from any compatible scanner.
 *
 * Note: This code was copied from https://github.com/fuadreza/flutter_barcode_listener/blob/master/lib/flutter_barcode_listener.dart
 *
 * If that code becomes available on pub.dev, we can remove this file and reference that library
 */

import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

typedef BarcodeScannedCallback = void Function(String barcode);

/// This widget will listen for raw PHYSICAL keyboard events
/// even when other controls have primary focus.
/// It will buffer all characters coming in specifed `bufferDuration` time frame
/// that end with line feed character and call callback function with result.
/// Keep in mind this widget will listen for events even when not visible.
/// Windows seems to be using the [RawKeyDownEvent] instead of the
/// [RawKeyUpEvent], this behaviour can be managed by setting [useKeyDownEvent].
class BarcodeKeyboardListener extends StatefulWidget {

  /// This widget will listen for raw PHYSICAL keyboard events
  /// even when other controls have primary focus.
  /// It will buffer all characters coming in specifed `bufferDuration` time frame
  /// that end with line feed character and call callback function with result.
  /// Keep in mind this widget will listen for events even when not visible.
  const BarcodeKeyboardListener(
      {Key? key,

        /// Child widget to be displayed.
        required this.child,

        /// Callback to be called when barcode is scanned.
        required Function(String) onBarcodeScanned,

        /// When experiencing issueswith empty barcodes on Windows,
        /// set this value to true. Default value is `false`.
        this.useKeyDownEvent = false,

        /// Maximum time between two key events.
        /// If time between two key events is longer than this value
        /// previous keys will be ignored.
        Duration bufferDuration = hundredMs})
      : _onBarcodeScanned = onBarcodeScanned,
        _bufferDuration = bufferDuration,
        super(key: key);

  final Widget child;
  final BarcodeScannedCallback _onBarcodeScanned;
  final Duration _bufferDuration;
  final bool useKeyDownEvent;

  @override
  _BarcodeKeyboardListenerState createState() => _BarcodeKeyboardListenerState(
      _onBarcodeScanned, _bufferDuration, useKeyDownEvent);
}

const Duration aSecond = Duration(seconds: 1);
const Duration hundredMs = Duration(milliseconds: 100);
const String lineFeed = "\n";

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {

  _BarcodeKeyboardListenerState(this._onBarcodeScannedCallback,
      this._bufferDuration, this._useKeyDownEvent) {
    RawKeyboard.instance.addListener(_keyBoardCallback);
    _keyboardSubscription =
        _controller.stream.where((char) => char != null).listen(onKeyEvent);
  }

  List<String> _scannedChars = [];
  DateTime? _lastScannedCharCodeTime;
  late StreamSubscription<String?> _keyboardSubscription;

  final BarcodeScannedCallback _onBarcodeScannedCallback;
  final Duration _bufferDuration;

  final _controller = StreamController<String?>();

  final bool _useKeyDownEvent;

  bool _isShiftPressed = false;
  void onKeyEvent(String? char) {
    //remove any pending characters older than bufferDuration value
    checkPendingCharCodesToClear();
    _lastScannedCharCodeTime = DateTime.now();
    if (char == lineFeed) {
      _onBarcodeScannedCallback.call(_scannedChars.join());
      resetScannedCharCodes();
    } else {
      //add character to list of scanned characters;
      _scannedChars.add(char!);
    }
  }

  void checkPendingCharCodesToClear() {
    if (_lastScannedCharCodeTime != null) {
      if (_lastScannedCharCodeTime!
          .isBefore(DateTime.now().subtract(_bufferDuration))) {
        resetScannedCharCodes();
      }
    }
  }

  void resetScannedCharCodes() {
    _lastScannedCharCodeTime = null;
    _scannedChars = [];
  }

  void addScannedCharCode(String charCode) {
    _scannedChars.add(charCode);
  }

  void _keyBoardCallback(RawKeyEvent keyEvent) {
    if (keyEvent.logicalKey.keyId > 255 &&
        keyEvent.data.logicalKey != LogicalKeyboardKey.enter &&
        keyEvent.data.logicalKey != LogicalKeyboardKey.shiftLeft) return;
    if ((!_useKeyDownEvent && keyEvent is RawKeyUpEvent) ||
        (_useKeyDownEvent && keyEvent is RawKeyDownEvent)) {
      if (keyEvent.data is RawKeyEventDataAndroid) {
        if (keyEvent.data.logicalKey == LogicalKeyboardKey.shiftLeft) {
          _isShiftPressed = true;
        } else {
          if (_isShiftPressed) {
            _isShiftPressed = false;
            _controller.sink.add(String.fromCharCode(
                ((keyEvent.data) as RawKeyEventDataAndroid).codePoint).toUpperCase());
          } else {
            _controller.sink.add(String.fromCharCode(
                ((keyEvent.data) as RawKeyEventDataAndroid).codePoint));
          }
        }
      } else if (keyEvent.data is RawKeyEventDataFuchsia) {
        _controller.sink.add(String.fromCharCode(
            ((keyEvent.data) as RawKeyEventDataFuchsia).codePoint));
      } else if (keyEvent.data.logicalKey == LogicalKeyboardKey.enter) {
        _controller.sink.add(lineFeed);
      } else if (keyEvent.data is RawKeyEventDataWeb) {
        _controller.sink.add(((keyEvent.data) as RawKeyEventDataWeb).keyLabel);
      } else if (keyEvent.data is RawKeyEventDataLinux) {
        _controller.sink
            .add(((keyEvent.data) as RawKeyEventDataLinux).keyLabel);
      } else if (keyEvent.data is RawKeyEventDataWindows) {
        _controller.sink.add(String.fromCharCode(
            ((keyEvent.data) as RawKeyEventDataWindows).keyCode));
      } else if (keyEvent.data is RawKeyEventDataMacOs) {
        _controller.sink
            .add(((keyEvent.data) as RawKeyEventDataMacOs).characters);
      } else if (keyEvent.data is RawKeyEventDataIos) {
        _controller.sink
            .add(((keyEvent.data) as RawKeyEventDataIos).characters);
      } else {
        _controller.sink.add(keyEvent.character);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _keyboardSubscription.cancel();
    _controller.close();
    RawKeyboard.instance.removeListener(_keyBoardCallback);
    super.dispose();
  }
}