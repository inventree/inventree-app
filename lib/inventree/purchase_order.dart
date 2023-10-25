import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/model.dart";

import "orders.dart";


// TODO: Replace these status codes with ones fetched from the API?
const int PO_STATUS_PENDING = 10;
const int PO_STATUS_PLACED = 20;
const int PO_STATUS_COMPLETE = 30;
const int PO_STATUS_CANCELLED = 40;
const int PO_STATUS_LOST = 50;
const int PO_STATUS_RETURNED = 60;

class InvenTreePurchaseOrder extends InvenTreeOrder {

  InvenTreePurchaseOrder() : super();

  InvenTreePurchaseOrder.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePurchaseOrder.fromJson(json);

  @override
  String get URL => "order/po/";

  @override
  List<String> get rolesRequired => ["purchase_order"];

  String get receive_url => "${url}receive/";

  @override
  Map<String, dynamic> formFields() {
    var fields = {
      "reference": {},
      "supplier": {
        "filters": {
          "is_supplier": true,
        },
      },
      "supplier_reference": {},
      "description": {},
      "project_code": {},
      "target_date": {},
      "link": {},
      "responsible": {},
      "contact": {
        "filters": {
          "company": supplierId,
        }
      },
    };

    if (!InvenTreeAPI().supportsProjectCodes) {
      fields.remove("project_code");
    }

    return fields;

  }

  @override
  Map<String, String> defaultGetFilters() {
    return {
      "supplier_detail": "true",
    };
  }

  @override
  Map<String, String> defaultListFilters() {
    return {
      "supplier_detail": "true",
    };
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

  bool get isOpen => status == PO_STATUS_PENDING || status == PO_STATUS_PLACED;

  bool get isPending => status == PO_STATUS_PENDING;

  bool get isPlaced => status == PO_STATUS_PLACED;

  bool get isFailed => status == PO_STATUS_CANCELLED || status == PO_STATUS_LOST || status == PO_STATUS_RETURNED;

  Future<List<InvenTreePOLineItem>> getLineItems() async {

    final results = await InvenTreePOLineItem().list(
        filters: {
          "order": "${pk}",
        }
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

    await api.post("${url}issue/", expectedStatusCode: 201);
  }

  /// Mark this order as "cancelled"
  Future<void> cancelOrder() async {
    if (!isOpen) {
      return;
    }

    await api.post("${url}cancel/", expectedStatusCode: 201);
  }
}

class InvenTreePOLineItem extends InvenTreeOrderLine {

  InvenTreePOLineItem() : super();

  InvenTreePOLineItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePOLineItem.fromJson(json);

  @override
  String get URL => "order/po-line/";

  @override
  List<String> get rolesRequired => ["purchase_order"];

  @override
  Map<String, dynamic> formFields() {
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
  Map<String, String> defaultGetFilters() {
    return {
      "part_detail": "true",
    };
  }

  @override
  Map<String, String> defaultListFilters() {
    return {
      "part_detail": "true",
    };
  }

  double get received => getDouble("received");

  bool get isComplete => received >= quantity;

  String get progressString => simpleNumberString(received) + " / " + simpleNumberString(quantity);

  double get outstanding => quantity - received;

  int get supplierPartId => getInt("part");

  InvenTreeSupplierPart? get supplierPart {

    dynamic detail = jsondata["supplier_part_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreeSupplierPart.fromJson(detail as Map<String, dynamic>);
    }
  }

  String get SKU => getString("SKU", subKey: "supplier_part_detail");

  double get purchasePrice => getDouble("purchase_price");
  
  String get purchasePriceCurrency => getString("purchase_price_currency");

  int get destination => getInt("destination");

  Map<String, dynamic> get destinationDetail => getMap("destination_detail");
}

/*
 * Class representing an attachment file against a PurchaseOrder object
 */
class InvenTreePurchaseOrderAttachment extends InvenTreeAttachment {

  InvenTreePurchaseOrderAttachment() : super();

  InvenTreePurchaseOrderAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get REFERENCE_FIELD => "order";

  @override
  String get URL => "order/po/attachment/";

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePurchaseOrderAttachment.fromJson(json);

}
