import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/api_form.dart";

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
    if (!data.containsKey("line_item")) {
      return onBarcodeUnknown(data);
    }

    barcodeSuccessTone();
    showSnackIcon(L10().allocated, success: true);
  }

  @override
  Future<void> onBarcodeUnhandled(Map<String, dynamic> data) async {

    if (!data.containsKey("action_required") || !data.containsKey("line_item")) {
      return super.onBarcodeUnhandled(data);
    }

    // Prompt user for extra information to create the allocation
    var fields = InvenTreeSOLineItem().allocateFormFields();

    // Update fields with data gathered from the API response
    fields["line_item"]?["value"] = data["line_item"];

    Map<String, dynamic> stock_filters = {
      "in_stock": true,
      "available": true,
    };

    if (data.containsKey("part")) {
      stock_filters["part"] = data["part"];
    }

    fields["stock_item"]?["filters"] = stock_filters;
    fields["stock_item"]?["value"] = data["stock_item"];

    fields["quantity"]?["value"] = data["quantity"];

    fields["shipment"]?["value"] = data["shipment"];
    fields["shipment"]?["filters"] = {
      "order": salesOrder!.pk.toString()
    };

    final context = OneContext().context!;

    launchApiForm(
      context,
      L10().allocateStock,
      salesOrder!.allocate_url,
    fields,
    method: "POST",
    icon: FontAwesomeIcons.rightToBracket,
    onSuccess: (data) async {
        showSnackIcon(L10().allocated, success: true);
    });
  }

  @override
  Future<void> onBarcodeUnknown(Map<String, dynamic> data) async {
    barcodeFailureTone();
    showSnackIcon(
        data["error"] as String? ?? L10().barcodeError,
        success: false
    );
  }
}