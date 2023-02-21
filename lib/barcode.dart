import "dart:io";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:one_context/one_context.dart";
import "package:qr_code_scanner/qr_code_scanner.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/supplier_part_detail.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/location_display.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/stock_detail.dart";


/*
 * Play an audible 'success' alert to the user.
 */
Future<void> barcodeSuccessTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    playAudioFile("sounds/barcode_scan.mp3");
  }
}

Future <void> barcodeFailureTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    playAudioFile("sounds/barcode_error.mp3");
  }
}


/* Generic class which "handles" a barcode, by communicating with the InvenTree server,
 * and handling match / unknown / error cases.
 *
 * Override functionality of this class to perform custom actions,
 * based on the response returned from the InvenTree server
 */
class BarcodeHandler {

  BarcodeHandler();

  String getOverlayText(BuildContext context) => "Barcode Overlay";

    Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
      // Called when the server "matches" a barcode
      // Override this function
    }

    Future<void> onBarcodeUnknown(Map<String, dynamic> data) async {
      // Called when the server does not know about a barcode
      // Override this function

      barcodeFailureTone();

      showSnackIcon(
        L10().barcodeNoMatch,
        success: false,
        icon: Icons.qr_code,
      );
    }

  // Called when the server returns an unhandled response
  Future<void> onBarcodeUnhandled(Map<String, dynamic> data) async {
      barcodeFailureTone();
      showServerError("barcode/", L10().responseUnknown, data.toString());
    }

    /*
     * Base function to capture and process barcode data.
     *
     * Returns true only if the barcode scanner should remain open
     */
    Future<void> processBarcode(QRViewController? _controller, String barcode, {String url = "barcode/"}) async {

      debug("Scanned barcode data: '${barcode}'");

      barcode = barcode.trim();

      // Empty barcode is invalid
      if (barcode.isEmpty) {

        barcodeFailureTone();

        showSnackIcon(
          L10().barcodeError,
          icon: FontAwesomeIcons.circleExclamation,
          success: false
        );

        return;
      }

      var response = await InvenTreeAPI().post(
          url,
          body: {
            "barcode": barcode,
          },
          expectedStatusCode: null,  // Do not show an error on "unexpected code"
      );

      debug("Barcode scan response" + response.data.toString());

      Map<String, dynamic> data = response.asMap();

      // Handle strange response from the server
      if (!response.isValid() || !response.isMap()) {
        onBarcodeUnknown({});

        showSnackIcon(L10().serverError, success: false);

        // We want to know about this one!
        await sentryReportMessage(
            "BarcodeHandler.processBarcode returned unexpected value",
            context: {
              "data": response.data?.toString() ?? "null",
              "barcode": barcode,
              "url": url,
              "statusCode": response.statusCode.toString(),
              "valid": response.isValid().toString(),
              "error": response.error,
              "errorDetail": response.errorDetail,
              "className": "${this}",
            }
        );
      } else if (data.containsKey("success")) {
        await onBarcodeMatched(data);
      } else if ((response.statusCode >= 400) || data.containsKey("error")) {
        await onBarcodeUnknown(data);
      } else {
        await onBarcodeUnhandled(data);
      }
    }
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

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    int pk = -1;

    String model = "";

    // The following model types can be matched with barcodes
    final List<String> validModels = [
      "part",
      "stockitem",
      "stocklocation",
      "supplierpart"
    ];

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


class InvenTreeQRView extends StatefulWidget {

  const InvenTreeQRView(this._handler, {Key? key}) : super(key: key);

  final BarcodeHandler _handler;

  @override
  State<StatefulWidget> createState() => _QRViewState();
}


class _QRViewState extends State<InvenTreeQRView> {

  _QRViewState() : super();

  final GlobalKey qrKey = GlobalKey(debugLabel: "QR");

  QRViewController? _controller;

  bool flash_status = false;

  bool currently_processing = false;

  Future<void> updateFlashStatus() async {
    final bool? status = await _controller?.getFlashStatus();

    flash_status = status != null && status;

    // Reload
    if (mounted) {
      setState(() {});
    }
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();

    if (mounted) {
      if (Platform.isAndroid) {
        _controller!.pauseCamera();
      }

      _controller!.resumeCamera();
    }
  }

  /* Callback function when the Barcode scanner view is initially created */
  void _onViewCreated(BuildContext context, QRViewController controller) {
    _controller = controller;

    controller.scannedDataStream.listen((barcode) {
      handleBarcode(barcode.code);
    });
  }

  /* Handle scanned data */
  Future<void> handleBarcode(String? data) async {

    // Empty or missing data, or we have navigated away
    if (!mounted || data == null || data.isEmpty) {
      return;
    }

    // Currently processing a barcode - return!
    if (currently_processing) {
      return;
    }

    setState(() {
      currently_processing = true;
    });

    // Pause camera functionality until we are done processing
    _controller?.pauseCamera();

    // processBarcode returns true if the scanner window is to remain open
    widget._handler.processBarcode(_controller, data).then((value) {
      // Re-start the process after some delay
      Future.delayed(Duration(milliseconds: 500)).then((value) {
        if (mounted) {
          _controller?.resumeCamera();
          currently_processing = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        appBar: AppBar(
          title: Text(L10().scanBarcode),
          actions: [
            IconButton(
              icon: Icon(Icons.flip_camera_android),
              onPressed: () {
                _controller?.flipCamera();
              }
            ),
            IconButton(
              icon: flash_status ? Icon(Icons.flash_off) : Icon(Icons.flash_on),
              onPressed: () {
                _controller?.toggleFlash();
                updateFlashStatus();
              },
            )
          ],
        ),
        body: Stack(
          children: <Widget>[
            Column(
              children: [
                Expanded(
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: (QRViewController controller) {
                      _onViewCreated(context, controller);
                    },
                    overlay: QrScannerOverlayShape(
                      borderColor: Colors.red,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 300,
                    ),
                  )
                )
              ]
            ),
            Center(
                child: Column(
                    children: [
                      Spacer(),
                      Padding(
                        child: Text(widget._handler.getOverlayText(context),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        padding: EdgeInsets.all(20),
                      ),
                    ]
                )
            )
          ],
        )
    );
  }
}

Future<void> scanQrCode(BuildContext context) async {
  Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeQRView(BarcodeScanHandler())));

  return;
}


/*
 * Construct a generic ListTile widget to link or un-link a custom barcode from a model.
 */
Widget customBarcodeActionTile(BuildContext context, RefreshableState state, String barcode, String model, int pk) {

  if (barcode.isEmpty) {
    return ListTile(
      title: Text(L10().barcodeAssign),
      subtitle: Text(L10().barcodeAssignDetail),
      leading: Icon(Icons.qr_code, color: COLOR_CLICK),
      trailing: Icon(Icons.qr_code_scanner),
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

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvenTreeQRView(handler)
          )
        );
      }
    );
  } else {
    return ListTile(
      title: Text(L10().barcodeUnassign),
      leading: Icon(Icons.qr_code, color: COLOR_CLICK),
      onTap: () async {
        InvenTreeAPI().unlinkBarcode({
          model: pk.toString()
        }).then((bool result) {
          showSnackIcon(
            result ? L10().requestSuccessful : L10().requestFailed,
            success: result,
          );

          state.refresh(context);
        });
      },
    );
  }
}
