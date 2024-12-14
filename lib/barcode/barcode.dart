import "package:flutter/material.dart";

import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/company/manufacturer_part_detail.dart";
import "package:inventree/widget/order/sales_order_detail.dart";
import "package:one_context/one_context.dart";


import "package:inventree/api.dart";
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
import "package:inventree/widget/company/company_detail.dart";
import "package:inventree/widget/company/supplier_part_detail.dart";


// Signal a barcode scan success to the user
Future<void> barcodeSuccess(String msg) async {

  barcodeSuccessTone();
  showSnackIcon(msg, success: true);
}

// Signal a barcode scan failure to the user
Future<void> barcodeFailure(String msg, dynamic extra) async {
  barcodeFailureTone();
  showSnackIcon(
      msg,
      success: false,
    onAction: () {
        if (hasContext()) {
          OneContext().showDialog(
              builder: (BuildContext context) =>
                  SimpleDialog(
                      title: Text(L10().barcodeError),
                      children: <Widget>[
                        ListTile(
                            title: Text(L10().responseData),
                            subtitle: Text(extra.toString())
                        )
                      ]
                  )
          );
        }
    }
  );
}

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
        icon: TablerIcons.exclamation_circle,
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

    var supplierPart = await InvenTreeSupplierPart().get(pk);

    if (supplierPart is InvenTreeSupplierPart) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(
          builder: (context) => SupplierPartDetailWidget(supplierPart)));
    }
  }

  /*
    * Response when a "ManufacturerPart" instance is scanned
   */
  Future<void> handleManufacturerPart(int pk) async {
    var manufacturerPart = await InvenTreeManufacturerPart().get(pk);

    if (manufacturerPart is InvenTreeManufacturerPart) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(
          builder: (context) => ManufacturerPartDetailWidget(manufacturerPart)));
    }
  }

  Future<void> handleCompany(int pk) async {
    var company = await InvenTreeCompany().get(pk);

    if (company is InvenTreeCompany) {
      OneContext().pop();
      OneContext().push(MaterialPageRoute(
          builder: (context) => CompanyDetailWidget(company)));
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
      InvenTreePart.MODEL_TYPE,
      InvenTreeCompany.MODEL_TYPE,
      InvenTreeStockItem.MODEL_TYPE,
      InvenTreeStockLocation.MODEL_TYPE,
      InvenTreeSupplierPart.MODEL_TYPE,
      InvenTreeManufacturerPart.MODEL_TYPE,
    ];


    if (InvenTreeAPI().supportsOrderBarcodes) {
      validModels.add(InvenTreePurchaseOrder.MODEL_TYPE);
      validModels.add(InvenTreeSalesOrder.MODEL_TYPE);
    }

    for (var key in validModels) {
      if (data.containsKey(key)) {
        try {
          pk = (data[key]?["pk"] ?? -1) as int;

          // Break on the first valid match found
          if (pk > 0) {
            model = key;
            break;
          }
        } catch (error, stackTrace) {
          sentryReportError("onBarcodeMatched", error, stackTrace);
        }
      }
    }

    // A valid result has been found
    if (pk > 0 && model.isNotEmpty) {

      barcodeSuccessTone();

      switch (model) {
        case InvenTreeStockItem.MODEL_TYPE:
          await handleStockItem(pk);
          return;
        case InvenTreePurchaseOrder.MODEL_TYPE:
          await handlePurchaseOrder(pk);
          return;
        case InvenTreeSalesOrder.MODEL_TYPE:
          await handleSalesOrder(pk);
          return;
        case InvenTreeStockLocation.MODEL_TYPE:
          await handleStockLocation(pk);
          return;
        case InvenTreeSupplierPart.MODEL_TYPE:
          await handleSupplierPart(pk);
          return;
        case InvenTreeManufacturerPart.MODEL_TYPE:
          await handleManufacturerPart(pk);
          return;
        case InvenTreePart.MODEL_TYPE:
          await handlePart(pk);
          return;
        case InvenTreeCompany.MODEL_TYPE:
          await handleCompany(pk);
          return;
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

          if (hasContext()) {
            OneContext().showDialog(
                builder: (BuildContext context) =>
                    SimpleDialog(
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
        }
    );
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
    if (!data.containsKey("hash") && !data.containsKey("barcode_hash")) {
      showServerError(
        "barcode/",
        L10().missingData,
        L10().barcodeMissingHash,
      );
    } else {
      String barcode;

      barcode = (data["barcode_data"] ?? "") as String;

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

  @override
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) async {
    await onBarcodeMatched(data);
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
