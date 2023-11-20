import "package:flutter/material.dart";

import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/order/sales_order_detail.dart";
import "package:one_context/one_context.dart";


import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/barcode/camera_controller.dart";
import "package:inventree/barcode/wedge_controller.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/tones.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/part/part_detail.dart";
import "package:inventree/widget/order/purchase_order_detail.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock/stock_detail.dart";
import "package:inventree/widget/company/supplier_part_detail.dart";


/*
 * Launch a barcode scanner with a particular context and handler.
 * 
 * - Can be called with a custom BarcodeHandler instance, or use the default handler
 * - Returns a Future which resolves when the scanner is dismissed
 * - The provided BarcodeHandler instance is used to handle the scanned barcode
 */
Future<Object?> scanBarcode(BuildContext context, {BarcodeHandler? handler}) async {

  // Default to generic scan handler
  handler ??= BarcodeScanHandler();
  
  InvenTreeBarcodeController controller = CameraBarcodeController(handler);

  // Select barcode controller based on user preference
  final int barcodeControllerType = await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_TYPE, BARCODE_CONTROLLER_CAMERA) as int;

  switch (barcodeControllerType) {
    case BARCODE_CONTROLLER_WEDGE:
      controller = WedgeBarcodeController(handler);
      break;
    case BARCODE_CONTROLLER_CAMERA:
    default:
      // Already set as default option
      break;
  }

  return Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, _, __) => controller,
      opaque: false,
    )
  );
}


/*
 * Class for general barcode scanning.
 * Scan *any* barcode without context, and then redirect app to correct view.
 *
 * Handles scanning of:
 *
 * - StockLocation
 * - StockItem
 * - Part
 * - SupplierPart
 * - PurchaseOrder
 */
class BarcodeScanHandler extends BarcodeHandler {

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanGeneral;

  @override
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) async {

    barcodeFailureTone();

    showSnackIcon(
        L10().barcodeNoMatch,
        icon: FontAwesomeIcons.circleExclamation,
        success: false,
    );
  }

  /*
   * Response when a "Part" instance is scanned
   */
  Future<void> handlePart(int pk) async {

    var part = await InvenTreePart().get(pk);

    if (part is InvenTreePart) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
    }
  }

  /*
   * Response when a "StockItem" instance is scanned
   */
  Future<void> handleStockItem(int pk) async {

    var item = await InvenTreeStockItem().get(pk);

    if (item is InvenTreeStockItem) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(
            builder: (context) => StockDetailWidget(item)));
    }
  }

  /*
   * Response when a "StockLocation" instance is scanned
   */
  Future<void> handleStockLocation(int pk) async {

    var loc = await InvenTreeStockLocation().get(pk);

    if (loc is InvenTreeStockLocation) {
      OneContext().pop();
      OneContext().navigator.push(MaterialPageRoute(
          builder: (context) => LocationDisplayWidget(loc)));
    }
  }

  /*
   * Response when a "SupplierPart" instance is scanned
   */
  Future<void> handleSupplierPart(int pk) async {

    var supplierpart = await InvenTreeSupplierPart().get(pk);

    if (supplierpart is InvenTreeSupplierPart) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(
          builder: (context) => SupplierPartDetailWidget(supplierpart)));
    }
  }


  /*
   * Response when a "PurchaseOrder" instance is scanned
   */
  Future<void> handlePurchaseOrder(int pk) async {
    var order = await InvenTreePurchaseOrder().get(pk);

    if (order is InvenTreePurchaseOrder) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(
        builder: (context) => PurchaseOrderDetailWidget(order)));
    }
  }

  // Response when a SalesOrder instance is scanned
  Future<void> handleSalesOrder(int pk) async {
    var order = await InvenTreeSalesOrder().get(pk);

    if (order is InvenTreeSalesOrder) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(
        builder: (context) => SalesOrderDetailWidget(order)));
    }
  }

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    int pk = -1;

    String model = "";

    // The following model types can be matched with barcodes
    List<String> validModels = [
      "part",
      "stockitem",
      "stocklocation",
      "supplierpart",
    ];


    if (InvenTreeAPI().supportsOrderBarcodes) {
      validModels.add("purchaseorder");
      validModels.add("salesorder");
    }

    for (var key in validModels) {
      if (data.containsKey(key)) {
        pk = (data[key]?["pk"] ?? -1) as int;

        // Break on the first valid match found
        if (pk > 0) {
          model = key;
          break;
        }
      }
    }

    // A valid result has been found
    if (pk > 0 && model.isNotEmpty) {

      barcodeSuccessTone();

      switch (model) {
        case "part":
          await handlePart(pk);
          return;
        case "stockitem":
          await handleStockItem(pk);
          return;
        case "stocklocation":
          await handleStockLocation(pk);
          return;
        case "supplierpart":
          await handleSupplierPart(pk);
          return;
        case "purchaseorder":
          await handlePurchaseOrder(pk);
          return;
        case "salesorder":
          await handleSalesOrder(pk);
          return;
          // TODO: Handle manufacturer part
        default:
          // Fall through to failure state
          break;
      }
    }

    // If we get here, we have not found a valid barcode result!
    barcodeFailureTone();

    showSnackIcon(
        L10().barcodeUnknown,
        success: false,
        onAction: () {

          OneContext().showDialog(
              builder: (BuildContext context) => SimpleDialog(
                title: Text(L10().unknownResponse),
                children: <Widget>[
                  ListTile(
                    title: Text(L10().responseData),
                    subtitle: Text(data.toString()),
                  )
                ],
              )
          );
        }
    );
  }
}


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


/*
 * Barcode handler for finding a "unique" barcode (one that does not match an item in the database)
 */
class UniqueBarcodeHandler extends BarcodeHandler {

  UniqueBarcodeHandler(this.callback, {this.overlayText = ""});

  // Callback function when a "unique" barcode hash is found
  final Function(String) callback;

  final String overlayText;

  @override
  String getOverlayText(BuildContext context) {
    if (overlayText.isEmpty) {
      return L10().barcodeScanAssign;
    } else {
      return overlayText;
    }
  }

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {

    barcodeFailureTone();

    // If the barcode is known, we can"t assign it to the stock item!
    showSnackIcon(
        L10().barcodeInUse,
        icon: Icons.qr_code,
        success: false
    );
  }

  @override
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) async {
    // If the barcode is unknown, we *can* assign it to the stock item!

    if (!data.containsKey("hash") && !data.containsKey("barcode_hash")) {
      showServerError(
        "barcode/",
        L10().missingData,
        L10().barcodeMissingHash,
      );
    } else {
      String barcode;

      if (InvenTreeAPI().supportModernBarcodes) {
        barcode = (data["barcode_data"] ?? "") as String;
      } else {
        // Legacy barcode API
        barcode = (data["hash"] ?? data["barcode_hash"] ?? "") as String;
      }

      if (barcode.isEmpty) {
        barcodeFailureTone();

        showSnackIcon(
          L10().barcodeError,
          success: false,
        );
      } else {

        barcodeSuccessTone();

        // Close the barcode scanner
        if (OneContext.hasContext) {
          OneContext().pop();
        }

        callback(barcode);
      }
    }
  }
}


SpeedDialChild customBarcodeAction(BuildContext context, RefreshableState state, String barcode, String model, int pk) {

  if (barcode.isEmpty) {
    return SpeedDialChild(
      label: L10().barcodeAssign,
      child: Icon(Icons.barcode_reader),
      onTap: () {
        var handler = UniqueBarcodeHandler((String barcode) {
          InvenTreeAPI().linkBarcode({
            model: pk.toString(),
            "barcode": barcode,
          }).then((bool result) {
            showSnackIcon(
                result ? L10().barcodeAssigned : L10().barcodeNotAssigned,
                success: result
            );

            state.refresh(context);
          });
        });
        scanBarcode(context, handler: handler);
      }
    );
  } else {
    return SpeedDialChild(
      child: Icon(Icons.barcode_reader),
      label: L10().barcodeUnassign,
      onTap: () {
        InvenTreeAPI().unlinkBarcode({
          model: pk.toString()
        }).then((bool result) {
          showSnackIcon(
            result ? L10().requestSuccessful : L10().requestFailed,
            success: result,
          );

          state.refresh(context);
        });
      }
    );
  }
}
