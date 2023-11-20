
import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/barcode/tones.dart";

import "package:inventree/inventree/sentry.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/snacks.dart";


/* Generic class which "handles" a barcode, by communicating with the InvenTree server,
 * and handling match / unknown / error cases.
 *
 * Override functionality of this class to perform custom actions,
 * based on the response returned from the InvenTree server
 */
class BarcodeHandler {

  BarcodeHandler();

  // Return the text to display on the barcode overlay
  // Note: Will be overridden by child classes
  String getOverlayText(BuildContext context) => "Barcode Overlay";

  // Called when the server "matches" a barcode
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    // Override this function
  }

  // Called when the server does not know about a barcode
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) async {
    // Override this function

    barcodeFailureTone();

    showSnackIcon(
      (data["error"] ?? L10().barcodeNoMatch) as String,
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
  Future<void> processBarcode(String barcode,
      {String url = "barcode/",
      Map<String, dynamic> extra_data = const {}}) async {
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
          ...extra_data,
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
