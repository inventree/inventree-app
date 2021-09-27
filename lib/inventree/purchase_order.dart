import 'package:inventree/inventree/company.dart';
import 'package:inventree/inventree/part.dart';

import 'model.dart';

// TODO: In the future, status codes should be retrieved from the server
const int PO_STATUS_PENDING = 10;
const int PO_STATUS_PLACED = 20;
const int PO_STATUS_COMPLETE = 30;
const int PO_STATUS_CANCELLED = 40;
const int PO_STATUS_LOST = 50;
const int PO_STATUS_RETURNED = 60;

class InvenTreePurchaseOrder extends InvenTreeModel {

  @override
  String get URL => "order/po/";

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

  InvenTreePurchaseOrder() : super();

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

  String get issueDate => jsondata['issue_date'] ?? "";

  String get completeDate => jsondata['complete_date'] ?? "";

  String get creationDate => jsondata['creation_date'] ?? "";

  String get targetDate => jsondata['target_date'] ?? "";

  int get lineItems => jsondata['line_items'] ?? 0;

  bool get overdue => jsondata['overdue'] ?? false;

  String get reference => jsondata['reference'] ?? "";

  int get responsible => jsondata['responsible'] ?? -1;

  int get supplierId => jsondata['supplier'] ?? -1;

  InvenTreeCompany? get supplier {

    dynamic supplier_detail = jsondata["supplier_detail"] ?? null;

    if (supplier_detail == null) {
      return null;
    } else {
      return InvenTreeCompany.fromJson(supplier_detail);
    }
  }

  String get supplierReference => jsondata['supplier_reference'] ?? "";

  int get status => jsondata['status'] ?? -1;

  String get statusText => jsondata['status_text'] ?? "";

  bool get isOpen => this.status == PO_STATUS_PENDING || this.status == PO_STATUS_PLACED;

  bool get isFailed => this.status == PO_STATUS_CANCELLED || this.status == PO_STATUS_LOST || this.status == PO_STATUS_RETURNED;

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

  InvenTreePurchaseOrder.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePurchaseOrder.fromJson(json);
  }
}

class InvenTreePOLineItem extends InvenTreeModel {
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

  double get quantity => jsondata['quantity'] ?? 0;

  double get received => jsondata['received'] ?? 0;

  String get reference => jsondata['reference'] ?? "";

  int get orderId => jsondata['order'] ?? -1;

  int get supplirtPartId => jsondata['part'] ?? -1;

  InvenTreePart? get part {
    dynamic part_detail = jsondata["part_detail"] ?? null;

    if (part_detail == null) {
      return null;
    } else {
      return InvenTreePart.fromJson(part_detail);
    }
  }

  double get purchasePrice => double.parse(jsondata['purchase_price']);

  String get purchasePriceCurrency => jsondata['purchase_price_currency'] ?? "";

  String get purchasePriceString => jsondata['purchase_price_string'] ?? "";

  int get destination => jsondata['destination'] ?? -1;

  Map<String, dynamic> get destinationDetail => jsondata['destination_detail'];

  InvenTreePOLineItem() : super();

  InvenTreePOLineItem.fromJson(Map<String, dynamic> json)
      : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePOLineItem.fromJson(json);
  }
}
