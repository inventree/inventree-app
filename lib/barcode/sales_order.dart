import "package:flutter/material.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:one_context/one_context.dart";

import "package:inventree/l10.dart";

import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/tones.dart";

import "package:inventree/widget/snacks.dart";


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


class SOAllocateStockHandler extends BarcodeHandler {

  SOAllocateStockHandler({this.salesOrder, this.lineItem, this.shipment});

  InvenTreeSalesOrder? salesOrder;
  InvenTreeSOLineItem? lineItem;
  InvenTreeSalesOrderShipment? shipment;

  @override
  String getOverlayText(BuildContext context) => L10().allocateStock;

  @override
  Future<void> processBarcode(String barcode,
  {
    String url = "barcode/so-allocate/",
    Map<String, dynamic> extra_data = const {}}) {

    final so_extra_data = {
      "sales_order": salesOrder?.pk,
      "shipment": shipment?.pk,
      "line": lineItem?.pk,
      ...extra_data
    };

    return super.processBarcode(barcode, url: url, extra_data: so_extra_data);
  }

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    // TODO
    return onBarcodeUnknown(data);
  }
}