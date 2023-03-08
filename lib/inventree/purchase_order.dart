import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";

import "package:inventree/inventree/model.dart";

// TODO: In the future, status codes should be retrieved from the server
const int PO_STATUS_PENDING = 10;
const int PO_STATUS_PLACED = 20;
const int PO_STATUS_COMPLETE = 30;
const int PO_STATUS_CANCELLED = 40;
const int PO_STATUS_LOST = 50;
const int PO_STATUS_RETURNED = 60;

class InvenTreePurchaseOrder extends InvenTreeModel {

  InvenTreePurchaseOrder() : super();

  InvenTreePurchaseOrder.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "order/po/";

  String get receive_url => "${url}receive/";

  @override
  Map<String, dynamic> formFields() {
    return {
      "reference": {},
      "supplier_reference": {},
      "description": {},
      "target_date": {},
      "link": {},
      "responsible": {},
    };
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

  String get issueDate => (jsondata["issue_date"] ?? "") as String;

  String get completeDate => (jsondata["complete_date"] ?? "") as String;

  String get creationDate => (jsondata["creation_date"] ?? "") as String;

  String get targetDate => (jsondata["target_date"] ?? "") as String;

  int get lineItemCount => (jsondata["line_items"] ?? 0) as int;

  bool get overdue => (jsondata["overdue"] ?? false) as bool;

  String get reference => (jsondata["reference"] ?? "") as String;

  int get responsibleId => (jsondata["responsible"] ?? -1) as int;

  int get supplierId => (jsondata["supplier"] ?? -1) as int;

  InvenTreeCompany? get supplier {

    dynamic supplier_detail = jsondata["supplier_detail"];

    if (supplier_detail == null) {
      return null;
    } else {
      return InvenTreeCompany.fromJson(supplier_detail as Map<String, dynamic>);
    }
  }

  String get supplierReference => (jsondata["supplier_reference"] ?? "") as String;

  int get status => (jsondata["status"] ?? -1) as int;

  String get statusText => (jsondata["status_text"] ?? "") as String;

  bool get isOpen => status == PO_STATUS_PENDING || status == PO_STATUS_PLACED;

  bool get isPlaced => status == PO_STATUS_PLACED;

  bool get isFailed => status == PO_STATUS_CANCELLED || status == PO_STATUS_LOST || status == PO_STATUS_RETURNED;

  double? get totalPrice {
    String price = (jsondata["total_price"] ?? "") as String;

    if (price.isEmpty) {
      return null;
    } else {
      return double.tryParse(price);
    }
  }

  String get totalPriceCurrency => (jsondata["total_price_currency"] ?? "") as String;

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

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePurchaseOrder.fromJson(json);
  }
}

class InvenTreePOLineItem extends InvenTreeModel {

  InvenTreePOLineItem() : super();

  InvenTreePOLineItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "order/po-line/";

  @override
  Map<String, dynamic> formFields() {
    return {
      // TODO: @Guusggg Not sure what will come here.
      // "quantity": {},
      // "reference": {},
      // "notes": {},
      // "order": {},
      // "part": {},
      "received": {},
      // "purchase_price": {},
      // "purchase_price_currency": {},
      // "destination": {}
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

  bool get isComplete => received >= quantity;

  double get quantity => (jsondata["quantity"] ?? 0) as double;

  double get received => (jsondata["received"] ?? 0) as double;

  double get outstanding => quantity - received;

  String get reference => (jsondata["reference"] ?? "") as String;

  int get orderId => (jsondata["order"] ?? -1) as int;

  int get supplierPartId => (jsondata["part"] ?? -1) as int;

  InvenTreePart? get part {
    dynamic part_detail = jsondata["part_detail"];

    if (part_detail == null) {
      return null;
    } else {
      return InvenTreePart.fromJson(part_detail as Map<String, dynamic>);
    }
  }

  InvenTreeSupplierPart? get supplierPart {

    dynamic detail = jsondata["supplier_part_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreeSupplierPart.fromJson(detail as Map<String, dynamic>);
    }
  }

  double get purchasePrice => double.parse((jsondata["purchase_price"] ?? "") as String);

  String get purchasePriceCurrency => (jsondata["purchase_price_currency"] ?? "") as String;

  String get purchasePriceString => (jsondata["purchase_price_string"] ?? "") as String;

  int get destination => (jsondata["destination"] ?? -1) as int;

  Map<String, dynamic> get destinationDetail => (jsondata["destination_detail"] ?? {}) as Map<String, dynamic>;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePOLineItem.fromJson(json);
  }
}

/*
 * Class representing an attachment file against a StockItem object
 */
class InvenTreePurchaseOrderAttachment extends InvenTreeAttachment {

  InvenTreePurchaseOrderAttachment() : super();

  InvenTreePurchaseOrderAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get REFERENCE_FIELD => "order";

  @override
  String get URL => "order/po/attachment/";

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePurchaseOrderAttachment.fromJson(json);
  }
}
