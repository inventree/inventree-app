import 'model.dart';

const int PO_STATUS_PENDING = 10;
const int PO_STATUS_PLACED = 20;
const int PO_STATUS_COMPLETE = 30;
const int PO_STATUS_CANCELLED = 40;
const int PO_STATUS_LOST = 50;
const int PO_STATUS_RETURNED = 60;

class InvenTreePO extends InvenTreeModel {
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

  InvenTreePO() : super();

  String get issueDate => jsondata['issue_date'] ?? "";
  String get completeDate => jsondata['complete_date'] ?? "";
  String get creationDate => jsondata['creation_date'] ?? "";
  String get targetDate => jsondata['target_date'] ?? "";

  int get lineItems => jsondata['line_items'] ?? 0;
  bool get overdue => jsondata['overdue'] ?? false;
  String get reference => jsondata['reference'] ?? "";
  int get responsible => jsondata['responsible'] ?? -1;

  int get supplier => jsondata['supplier'] ?? -1;
  String get supplierReference => jsondata['supplier_reference'] ?? "";

  int get status => jsondata['status'] ?? -1;
  String get statusText => jsondata['status_text'] ?? "";

  bool get isOpen =>
      this.status == PO_STATUS_PENDING || this.status == PO_STATUS_PLACED;

  bool get isFailed =>
      this.status == PO_STATUS_CANCELLED ||
      this.status == PO_STATUS_LOST ||
      this.status == PO_STATUS_RETURNED;

  InvenTreePO.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePO.fromJson(json);
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

// TODO: @Guusggg Incomplete as I currently can't test it.
class InvenTreeSO extends InvenTreeModel {
  @override
  String get URL => "order/so/";

  @override
  Map<String, dynamic> formFields() {
    return {
      "reference": {},
      "customer": {},
      "customer_reference": {},
      "description": {},
      "target_date": {},
      "link": {},
      "responsible": {},
    };
  }

  InvenTreeSO() : super();

  InvenTreeSO.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreeSO.fromJson(json);
  }
}

// TODO: @Guusggg Incomplete as I currently can't test it.
class InvenTreeSOLineItem {}
