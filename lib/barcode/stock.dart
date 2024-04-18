import "package:flutter/cupertino.dart";
import "package:one_context/one_context.dart";

import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/tones.dart";

import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/snacks.dart";


/*
 * Generic class for scanning a StockLocation.
 *
 * - Validates that the scanned barcode matches a valid StockLocation
 * - Runs a "callback" function if a valid StockLocation is found
 */
class BarcodeScanStockLocationHandler extends BarcodeHandler {

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanLocation;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {

    // We expect that the barcode points to a 'stocklocation'
    if (data.containsKey("stocklocation")) {
      int _loc = (data["stocklocation"]["pk"] ?? -1) as int;

      // A valid stock location!
      if (_loc > 0) {

        debug("Scanned stock location ${_loc}");

        final bool result = await onLocationScanned(_loc);

        if (result && OneContext.hasContext) {
          OneContext().pop();
          return;
        }
      }
    }

    // If we get to this point, something went wrong during the scan process
    barcodeFailureTone();

    showSnackIcon(
      L10().invalidStockLocation,
      success: false,
    );
  }

  // Callback function which runs when a valid StockLocation is scanned
  // If this function returns 'true' the barcode scanning dialog will be closed
  Future<bool> onLocationScanned(int locationId) async {
    // Re-implement this for particular subclass
    return false;
  }

}


/*
 * Generic class for scanning a StockItem
 *
 * - Validates that the scanned barcode matches a valid StockItem
 * - Runs a "callback" function if a valid StockItem is found
 */
class BarcodeScanStockItemHandler extends BarcodeHandler {

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanItem;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    // We expect that the barcode points to a 'stockitem'
    if (data.containsKey("stockitem")) {
      int _item = (data["stockitem"]["pk"] ?? -1) as int;

      // A valid stock location!
      if (_item > 0) {

        barcodeSuccessTone();

        bool result = await onItemScanned(_item);

        if (result && OneContext.hasContext) {
          OneContext().pop();
          return;
        }
      }
    }

    // If we get to this point, something went wrong during the scan process
    barcodeFailureTone();

    showSnackIcon(
      L10().invalidStockItem,
      success: false,
    );
  }

  // Callback function which runs when a valid StockItem is scanned
  Future<bool> onItemScanned(int itemId) async {
    // Re-implement this for particular subclass
    return false;
  }
}


/*
 * Barcode handler for scanning a provided StockItem into a scanned StockLocation.
 *
 * - The class is initialized by passing a valid StockItem object
 * - Expects to scan barcode for a StockLocation
 * - The StockItem is transferred into the scanned location
 */
class StockItemScanIntoLocationHandler extends BarcodeScanStockLocationHandler {

  StockItemScanIntoLocationHandler(this.item);

  final InvenTreeStockItem item;

  @override
  Future<bool> onLocationScanned(int locationId) async {

    final result = await item.transferStock(locationId);

    if (result) {
      barcodeSuccessTone();
      showSnackIcon(L10().barcodeScanIntoLocationSuccess, success: true);
    } else {
      barcodeFailureTone();
      showSnackIcon(L10().barcodeScanIntoLocationFailure, success: false);
    }

    return result;
  }
}


/*
 * Barcode handler for scanning stock item(s) into the specified StockLocation.
 *
 * - The class is initialized by passing a valid StockLocation object
 * - Expects to scan a barcode for a StockItem
 * - The scanned StockItem is transferred into the provided StockLocation
 */
class StockLocationScanInItemsHandler extends BarcodeScanStockItemHandler {

  StockLocationScanInItemsHandler(this.location);

  final InvenTreeStockLocation location;

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanItem;

  @override
  Future<bool> onItemScanned(int itemId) async {

    final InvenTreeStockItem? item = await InvenTreeStockItem().get(itemId) as InvenTreeStockItem?;

    bool result = false;

    if (item != null) {

      // Item is already *in* the specified location
      if (item.locationId == location.pk) {
        barcodeFailureTone();
        showSnackIcon(L10().itemInLocation, success: true);
        return false;
      } else {
        result = await item.transferStock(location.pk);
      }
    }

    showSnackIcon(
        result ? L10().barcodeScanIntoLocationSuccess : L10().barcodeScanIntoLocationFailure,
        success: result
    );

    // We always return false here, to ensure the barcode scan dialog remains open
    return false;
  }
}


/*
 * Barcode handler class for scanning a StockLocation into another StockLocation
 *
 * - The class is initialized by passing a valid StockLocation object
 * - Expects to scan barcode for another *parent* StockLocation
 * - The scanned StockLocation is set as the "parent" of the provided StockLocation
 */
class ScanParentLocationHandler extends BarcodeScanStockLocationHandler {

  ScanParentLocationHandler(this.location);

  final InvenTreeStockLocation location;

  @override
  Future<bool> onLocationScanned(int locationId) async {

    final response = await location.update(
      values: {
        "parent": locationId.toString(),
      },
      expectedStatusCode: null,
    );

    switch (response.statusCode) {
      case 200:
      case 201:
        barcodeSuccessTone();
        showSnackIcon(L10().barcodeScanIntoLocationSuccess, success: true);
        return true;
      case 400:  // Invalid parent location chosen
        barcodeFailureTone();
        showSnackIcon(L10().invalidStockLocation, success: false);
        return false;
      default:
        barcodeFailureTone();
        showSnackIcon(
            L10().barcodeScanIntoLocationFailure,
            success: false,
            actionText: L10().details,
            onAction: () {
              showErrorDialog(
                L10().barcodeError,
                response: response,
              );
            }
        );
        return false;
    }
  }
}
