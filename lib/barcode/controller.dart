import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/widget/barcode_scan_log.dart";
import "package:inventree/widget/progress.dart";

/*
 * Generic class which provides a barcode scanner interface.
 * 
 * When the controller is instantiated, it is passed a "handler" class,
 * which is used to process the scanned barcode.
 */
class InvenTreeBarcodeController extends StatefulWidget {
  const InvenTreeBarcodeController(this.handler, {Key? key}) : super(key: key);

  final BarcodeHandler handler;

  @override
  State<StatefulWidget> createState() => InvenTreeBarcodeControllerState();
}

/*
 * Base state widget for the barcode controller.
 * This defines the basic interface for the barcode controller.
 */
class InvenTreeBarcodeControllerState
    extends State<InvenTreeBarcodeController> {
  InvenTreeBarcodeControllerState() : super();

  final GlobalKey barcodeControllerKey = GlobalKey(
    debugLabel: "barcodeController",
  );

  // Internal state flag to test if we are currently processing a barcode
  bool processingBarcode = false;

  /*
   * Method to handle scanned data.
   * Any implementing class should call this method when a barcode is scanned.
   * Barcode data should be passed as a string
   */
  Future<void> handleBarcodeData(String? data) async {
    // Check that the data is valid, and this view is still mounted
    if (!mounted || data == null || data.isEmpty) {
      return;
    }

    // Currently processing a barcode - ignore this one
    if (processingBarcode) {
      return;
    }

    setState(() {
      processingBarcode = true;
    });

    showLoadingOverlay();
    await pauseScan();

    await widget.handler.processBarcode(data);

    // processBarcode may have popped the context
    if (!mounted) {
      hideLoadingOverlay();
      return;
    }

    int delay =
        await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_DELAY, 500)
            as int;

    Future.delayed(Duration(milliseconds: delay), () {
      hideLoadingOverlay();
      if (mounted) {
        resumeScan().then((_) {
          if (mounted) {
            setState(() {
              processingBarcode = false;
            });
          }
        });
      }
    });
  }

  // Hook function to "pause" the barcode scanner
  Future<void> pauseScan() async {
    // Implement this function in subclass
  }

  // Hook function to "resume" the barcode scanner
  Future<void> resumeScan() async {
    // Implement this function in subclass
  }

  // Hook function: return true if scanning is currently paused
  bool get isScanPaused => false;

  /*
   * Open a page over the scanner, pausing scanning while it is displayed.
   * Scanning is only resumed if it was running beforehand.
   */
  Future<void> _openOverScanner(Widget page) async {
    final bool wasPaused = isScanPaused;

    if (!wasPaused) {
      await pauseScan();
    }

    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    if (!wasPaused && mounted && !processingBarcode) {
      await resumeScan();
    }
  }

  // Open the barcode scan log
  Future<void> showScanLog() => _openOverScanner(const BarcodeScanLogWidget());

  // When this scanner was opened
  final DateTime openedAt = DateTime.now();

  // Bar at the bottom of the scanner which shows the most recent scan
  // (starts empty - only scans made since this scanner opened are shown)
  Widget buildLastScanBar() {
    return BarcodeLastScanBar(
      since: openedAt,
      onTap: (entry) =>
          _openOverScanner(BarcodeScanLogDetailWidget(entry: entry)),
    );
  }

  // App bar action which opens the barcode scan log
  Widget buildScanLogAction() {
    return IconButton(
      key: const Key("barcodeScanLog"),
      icon: const Icon(TablerIcons.history),
      tooltip: L10().barcodeScanLog,
      onPressed: showScanLog,
    );
  }

  /*
   * Implementing classes are in control of building out the widget
   */
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
