import "package:flutter/material.dart";
import "package:one_context/one_context.dart";

import "package:inventree/preferences.dart";

import "package:inventree/barcode/handler.dart";

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
class InvenTreeBarcodeControllerState extends State<InvenTreeBarcodeController> {

  InvenTreeBarcodeControllerState() : super();

  final GlobalKey barcodeControllerKey = GlobalKey(debugLabel: "barcodeController");

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

    BuildContext? context = OneContext.hasContext ? OneContext().context : null;

    showLoadingOverlay(context);
    await pauseScan();

    await widget.handler.processBarcode(data);

    // processBarcode may have popped the context
    if (!mounted) {
      hideLoadingOverlay();
      return;
    }

    int delay = await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_DELAY, 500) as int;

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

  /*
   * Implementing classes are in control of building out the widget
   */
  @override
  Widget build(BuildContext context) {
    return Container();
  }

}