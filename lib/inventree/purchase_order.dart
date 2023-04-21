import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/model.dart";

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

  @override
  List<String> get rolesRequired => ["purchase_order"];

  String get receive_url => "${url}receive/";

  @override
  Map<String, dynamic> formFields() {
    return {
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

  String get issueDate => getString("issue_date");

  String get completeDate => getString("complete_date");

  String get creationDate => getString("creation_date");

  String get targetDate => getString("target_date");

  int get lineItemCount => getInt("line_items", backup: 0);
  
  bool get overdue => getBool("overdue");

  String get reference => getString("reference");

  int get responsibleId => getInt("responsible");

  int get supplierId => getInt("supplier");

  // Project code information
  int get projectCodeId => getInt("project_code");

  String get projectCode => getString("code", subKey: "project_code_detail");

  String get projectCodeDescription => getString("description", subKey: "project_code_detail");

  bool get hasProjectCode => projectCode.isNotEmpty;

  InvenTreeCompany? get supplier {

    dynamic supplier_detail = jsondata["supplier_detail"];

    if (supplier_detail == null) {
      return null;
    } else {
      return InvenTreeCompany.fromJson(supplier_detail as Map<String, dynamic>);
    }
  }

  String get supplierReference => getString("supplier_reference");

  int get status => getInt("status");

  String get statusText => getString("status_text");

  bool get isOpen => status == PO_STATUS_PENDING || status == PO_STATUS_PLACED;

  bool get isPending => status == PO_STATUS_PENDING;

  bool get isPlaced => status == PO_STATUS_PLACED;

  bool get isFailed => status == PO_STATUS_CANCELLED || status == PO_STATUS_LOST || status == PO_STATUS_RETURNED;

  double? get totalPrice {
    String price = getString("total_price");

    if (price.isEmpty) {
      return null;
    } else {
      return double.tryParse(price);
    }
  }

  String get totalPriceCurrency => getString("total_price_currency");

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
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePurchaseOrder.fromJson(json);

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

  double get quantity => getDouble("quantity");

  double get received => getDouble("received");

  double get outstanding => quantity - received;

  String get reference => getString("reference");

  int get orderId => getInt("order");

  int get supplierPartId => getInt("part");

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

  double get purchasePrice => getDouble("purchase_price");
  
  String get purchasePriceCurrency => getString("purchase_price_currency");

  String get purchasePriceString => getString("purchase_price_string");

  int get destination => getInt("destination");

  Map<String, dynamic> get destinationDetail => getMap("destination_detail");
  
  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePOLineItem.fromJson(json);

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
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePurchaseOrderAttachment.fromJson(json);

}
