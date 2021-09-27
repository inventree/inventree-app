import 'package:inventree/inventree/company.dart';

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
      "supplier": {},
      "supplier_reference": {},
      "description": {},
      "target_date": {},
      "link": {},
      "responsible": {},
    };
  }

  InvenTreePurchaseOrder() : super();

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

  InvenTreeCompany get supplier {

    dynamic supplier_detail = jsondata["supplier_detail"] ?? {};

    return InvenTreeCompany.fromJson(supplier_detail);
  }

  String get supplierReference => jsondata['supplier_reference'] ?? "";

  int get status => jsondata['status'] ?? -1;

  String get statusText => jsondata['status_text'] ?? "";

  bool get isOpen => this.status == PO_STATUS_PENDING || this.status == PO_STATUS_PLACED;

  bool get isFailed => this.status == PO_STATUS_CANCELLED || this.status == PO_STATUS_LOST || this.status == PO_STATUS_RETURNED;

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

  double get quantity => jsondata['quantity'] ?? 0;

  double get received => jsondata['received'] ?? 0;

  String get reference => jsondata['reference'] ?? "";

  int get order => jsondata['order'] ?? -1;

  int get part => jsondata['part'] ?? -1;

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
