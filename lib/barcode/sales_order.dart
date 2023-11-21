import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:one_context/one_context.dart";

import "package:inventree/l10.dart";
import "package:inventree/api_form.dart";

import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/tones.dart";

import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/snacks.dart";
import "package:qr_code_scanner/qr_code_scanner.dart";


/*
 * Barcode handler class for scanning a new part into a SalesOrder
 */

class SOAddItemBarcodeHandler extends BarcodeHandler {

  SOAddItemBarcodeHandler({this.salesOrder});

  InvenTreeSalesOrder? salesOrder;

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanPart;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {

    // Extract the part ID from the returned data
    int part_id = -1;

    if (data.containsKey("part")) {
      part_id = (data["part"] ?? {} as Map<String, dynamic>)["pk"] as int;
    }

    if (part_id <= 0) {
      return onBarcodeUnknown(data);
    }

    // Request the part from the server
    var part = await InvenTreePart().get(part_id);

    if (part is InvenTreePart) {

      if (part.isSalable) {
        // Dispose of the barcode scanner
        if (OneContext.hasContext) {
          OneContext().pop();
        }

        final context = OneContext().context!;

        var fields = InvenTreeSOLineItem().formFields();

        fields["order"]?["value"] = salesOrder!.pk;
        fields["order"]?["hidden"] = true;

        fields["part"]?["value"] = part.pk;
        fields["part"]?["hidden"] = false;

        InvenTreeSOLineItem().createForm(
          context,
          L10().lineItemAdd,
          fields: fields,
        );

      } else {
        barcodeFailureTone();
        showSnackIcon(L10().partNotSalable, success: false);
      }

    } else {
      // Failed to fetch part
      return onBarcodeUnknown(data);
    }

  }

}