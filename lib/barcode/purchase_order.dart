import "package:flutter/material.dart";
import "package:inventree/preferences.dart";
import "package:one_context/one_context.dart";
import "package:inventree/l10.dart";

import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/tones.dart";

import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/snacks.dart";

/*
 * Barcode handler class for scanning a supplier barcode to receive a part
 *
 * - The class can be initialized by optionally passing a valid, placed PurchaseOrder object
 * - Expects to scan supplier barcode, possibly containing order_number and quantity
 * - If location or quantity information wasn't provided, show a form to fill it in
 */
class POReceiveBarcodeHandler extends BarcodeHandler {

  POReceiveBarcodeHandler({this.purchaseOrder, this.location});

  InvenTreePurchaseOrder? purchaseOrder;
  InvenTreeStockLocation? location;

  @override
  String getOverlayText(BuildContext context) => L10().barcodeReceivePart;

  @override
  Future<void> processBarcode(String barcode,
      {String url = "barcode/po-receive/",
        Map<String, dynamic> extra_data = const {}}) async {

    final bool confirm = await InvenTreeSettingsManager().getBool(INV_PO_CONFIRM_SCAN, true);

    final po_extra_data = {
      "purchase_order": purchaseOrder?.pk,
      "location": location?.pk,
      "auto_allocate": !confirm,
      ...extra_data,
    };

    return super.processBarcode(barcode, url: url, extra_data: po_extra_data);
  }

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {

    if (data.containsKey("lineitem") || data.containsKey("success")) {
      barcodeSuccess(L10().receivedItem);
      return;
    } else {
      return onBarcodeUnknown(data);
    }
  }

  @override
  Future<void> onBarcodeUnhandled(Map<String, dynamic> data) async {
    if (!data.containsKey("action_required") || !data.containsKey("lineitem")) {
      return super.onBarcodeUnhandled(data);
    }

    final lineItemData = data["lineitem"] as Map<String, dynamic>;
    if (!lineItemData.containsKey("pk") || !lineItemData.containsKey("purchase_order")) {
      barcodeFailureTone();
      showSnackIcon(L10().missingData, success: false);
    }

    // At minimum, we need the line item ID value
    final int? lineItemId = lineItemData["pk"] as int?;

    if (lineItemId == null) {
      barcodeFailureTone();
      return;
    }

    InvenTreePOLineItem? lineItem = await InvenTreePOLineItem().get(lineItemId) as InvenTreePOLineItem?;

    if (lineItem == null) {
      barcodeFailureTone();
      return;
    }

    // Next, extract the "optional" fields

    // Extract information from the returned server response
    double? quantity = double.tryParse((lineItemData["quantity"] ?? "0").toString());
    int? destination = lineItemData["location"] as int?;
    String? barcode = data["barcode_data"] as String?;

    // Discard the barcode scanner at this stage
    if (OneContext.hasContext) {
      OneContext().pop();
    }

    await lineItem.receive(
      OneContext().context!,
      destination: destination,
      quantity: quantity,
      barcode: barcode,
      onSuccess: () {
        showSnackIcon(L10().receivedItem, success: true);
      }
    );
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


/*
 * Barcode handler to add a line item to a purchase order
 */
class POAllocateBarcodeHandler extends BarcodeHandler {

  POAllocateBarcodeHandler({this.purchaseOrder});

  InvenTreePurchaseOrder? purchaseOrder;

  @override
  String getOverlayText(BuildContext context) => L10().scanSupplierPart;

  @override
  Future<void> processBarcode(String barcode, {
    String url = "barcode/po-allocate/",
    Map<String, dynamic> extra_data = const {}}
  ) {

    final po_extra_data = {
      "purchase_order": purchaseOrder?.pk,
      ...extra_data,
    };

    return super.processBarcode(
      barcode,
      url: url,
      extra_data: po_extra_data,
    );
  }

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    // Server must respond with a suppliertpart instance
    if (!data.containsKey("supplierpart")) {
      return onBarcodeUnknown(data);
    }

    dynamic supplier_part = data["supplierpart"];

    int supplier_part_pk = -1;

    if (supplier_part is Map<String, dynamic>) {
      supplier_part_pk = (supplier_part["pk"] ?? -1) as int;
    } else {
      return onBarcodeUnknown(data);
    }

    // Dispose of the barcode scanner
    if (OneContext.hasContext) {
      OneContext().pop();
    }

    final context = OneContext().context!;

    var fields = InvenTreePOLineItem().formFields();

    fields["order"]?["value"] = purchaseOrder!.pk;
    fields["part"]?["hidden"] = false;
    fields["part"]?["value"] = supplier_part_pk;

    InvenTreePOLineItem().createForm(
      context,
      L10().lineItemAdd,
      fields: fields,
    );
  }

  @override
  Future<void> onBarcodeUnhandled(Map<String, dynamic> data) async {

    print("onBarcodeUnhandled:");
    print(data.toString());

    super.onBarcodeUnhandled(data);
  }
}