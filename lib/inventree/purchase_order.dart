import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/orders.dart";
import "package:inventree/widget/order/extra_line_detail.dart";
import "package:inventree/widget/order/purchase_order_detail.dart";
import "package:inventree/widget/progress.dart";

import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";

/*
 * Class representing an individual PurchaseOrder instance
 */
class InvenTreePurchaseOrder extends InvenTreeOrder {
  InvenTreePurchaseOrder() : super();

  InvenTreePurchaseOrder.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePurchaseOrder.fromJson(json);

  @override
  String get URL => "order/po/";

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PurchaseOrderDetailWidget(this)),
    );
  }

  static const String MODEL_TYPE = "purchaseorder";

  @override
  List<String> get rolesRequired => ["purchase_order"];

  String get receive_url => "${url}receive/";

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "reference": {},
      "supplier": {
        "filters": {"is_supplier": true},
      },
      "supplier_reference": {},
      "description": {},
      "project_code": {},
      "destination": {},
      "start_date": {},
      "target_date": {},
      "link": {},
      "responsible": {},
      "contact": {
        "filters": {"company": supplierId},
      },
    };

    if (!InvenTreeAPI().supportsProjectCodes) {
      fields.remove("project_code");
    }

    if (!InvenTreeAPI().supportsPurchaseOrderDestination) {
      fields.remove("destination");
    }

    if (!InvenTreeAPI().supportsStartDate) {
      fields.remove("start_date");
    }

    return fields;
  }

  @override
  Map<String, String> defaultFilters() {
    return {"supplier_detail": "true"};
  }

  int get supplierId => getInt("supplier");

  InvenTreeCompany? get supplier {
    dynamic supplier_detail = jsondata["supplier_detail"];

    if (supplier_detail == null) {
      return null;
    } else {
      return InvenTreeCompany.fromJson(supplier_detail as Map<String, dynamic>);
    }
  }

  String get supplierReference => getString("supplier_reference");

  int get destinationId => getInt("destination");

  bool get isOpen => api.PurchaseOrderStatus.isNameIn(status, [
    "PENDING",
    "PLACED",
    "ON_HOLD",
  ]);

  bool get isPending =>
      api.PurchaseOrderStatus.isNameIn(status, ["PENDING", "ON_HOLD"]);

  bool get isPlaced => api.PurchaseOrderStatus.isNameIn(status, ["PLACED"]);

  bool get isFailed => api.PurchaseOrderStatus.isNameIn(status, [
    "CANCELLED",
    "LOST",
    "RETURNED",
  ]);

  Future<List<InvenTreePOLineItem>> getLineItems() async {
    final results = await InvenTreePOLineItem().list(
      filters: {"order": "${pk}"},
    );

    List<InvenTreePOLineItem> items = [];

    for (var result in results) {
      if (result is InvenTreePOLineItem) {
        items.add(result);
      }
    }

    return items;
  }

  /// Mark this order as "placed" / "issued"
  Future<void> issueOrder() async {
    // Order can only be placed when the order is 'pending'
    if (!isPending) {
      return;
    }

    showLoadingOverlay();
    await api.post("${url}issue/", expectedStatusCode: 201);
    hideLoadingOverlay();
  }

  /// Mark this order as "cancelled"
  Future<void> cancelOrder() async {
    if (!isOpen) {
      return;
    }

    showLoadingOverlay();
    await api.post("${url}cancel/", expectedStatusCode: 201);
    hideLoadingOverlay();
  }
}

class InvenTreePOLineItem extends InvenTreeOrderLine {
  InvenTreePOLineItem() : super();

  InvenTreePOLineItem.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePOLineItem.fromJson(json);

  @override
  String get URL => "order/po-line/";

  @override
  List<String> get rolesRequired => ["purchase_order"];

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "part": {
        // We cannot edit the supplier part field here
        "hidden": true,
      },
      "order": {
        // We cannot edit the order field here
        "hidden": true,
      },
      "reference": {},
      "quantity": {},
      "purchase_price": {},
      "purchase_price_currency": {},
      "destination": {},
      "notes": {},
      "link": {},
    };
  }

  @override
  Map<String, String> defaultFilters() {
    return {"part_detail": "true", "order_detail": "true"};
  }

  double get received => getDouble("received");

  bool get isComplete => received >= quantity;

  double get progressRatio {
    if (quantity <= 0 || received <= 0) {
      return 0;
    }

    return received / quantity;
  }

  String get progressString =>
      simpleNumberString(received) + " / " + simpleNumberString(quantity);

  double get outstanding => quantity - received;

  int get supplierPartId => getInt("part");

  String get partImage {
    String img = getString("thumbnail", subKey: "part_detail");

    if (img.isEmpty) {
      img = getString("image", subKey: "part_detail");
    }

    return img;
  }

  InvenTreeSupplierPart? get supplierPart {
    dynamic detail = jsondata["supplier_part_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreeSupplierPart.fromJson(detail as Map<String, dynamic>);
    }
  }

  InvenTreePurchaseOrder? get purchaseOrder {
    dynamic detail = jsondata["order_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreePurchaseOrder.fromJson(detail as Map<String, dynamic>);
    }
  }

  String get SKU => getString("SKU", subKey: "supplier_part_detail");

  double get purchasePrice => getDouble("purchase_price");

  String get purchasePriceCurrency => getString("purchase_price_currency");

  int get destinationId => getInt("destination");

  Map<String, dynamic> get orderDetail => getMap("order_detail");

  Map<String, dynamic> get destinationDetail => getMap("destination_detail");

  // Receive this line item into stock
  Future<void> receive(
    BuildContext context, {
    int? destination,
    double? quantity,
    String? barcode,
    Function? onSuccess,
  }) async {
    // Infer the destination location from the line item if not provided
    if (destinationId > 0) {
      destination = destinationId;
    }

    destination ??= (orderDetail["destination"]) as int?;

    quantity ??= outstanding;

    // Construct form fields
    Map<String, dynamic> fields = {
      "line_item": {
        "parent": "items",
        "nested": true,
        "hidden": true,
        "value": pk,
      },
      "quantity": {"parent": "items", "nested": true, "value": quantity},
      "location": {},
      "status": {"parent": "items", "nested": true},
      "batch_code": {"parent": "items", "nested": true},
      "barcode": {
        "parent": "items",
        "nested": true,
        "type": "barcode",
        "label": L10().barcodeAssign,
        "value": barcode,
        "required": false,
      },
    };

    if (destination != null && destination > 0) {
      fields["location"]?["value"] = destination;
    }

    InvenTreePurchaseOrder? order = purchaseOrder;

    if (order != null) {
      await launchApiForm(
        context,
        L10().receiveItem,
        order.receive_url,
        fields,
        method: "POST",
        icon: TablerIcons.transition_right,
        onSuccess: (data) {
          if (onSuccess != null) {
            onSuccess();
          }
        },
      );
    }
  }
}

class InvenTreePOExtraLineItem extends InvenTreeExtraLineItem {
  InvenTreePOExtraLineItem() : super();

  InvenTreePOExtraLineItem.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePOExtraLineItem.fromJson(json);

  @override
  String get URL => "order/po-extra-line/";

  @override
  List<String> get rolesRequired => ["purchase_order"];

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ExtraLineDetailWidget(this)),
    );
  }
}

/*
 * Class representing an attachment file against a PurchaseOrder object
 */
class InvenTreePurchaseOrderAttachment extends InvenTreeAttachment {
  InvenTreePurchaseOrderAttachment() : super();

  InvenTreePurchaseOrderAttachment.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  String get REFERENCE_FIELD => "order";

  @override
  String get REF_MODEL_TYPE => "purchaseorder";

  @override
  String get URL => InvenTreeAPI().supportsModernAttachments
      ? "attachment/"
      : "order/po/attachment/";

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePurchaseOrderAttachment.fromJson(json);
}
