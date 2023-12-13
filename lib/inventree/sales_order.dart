

import "package:inventree/helpers.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/orders.dart";

import "package:inventree/api.dart";


/*
 * Class representing an individual SalesOrder
 */
class InvenTreeSalesOrder extends InvenTreeOrder {

  InvenTreeSalesOrder() : super();

  InvenTreeSalesOrder.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeSalesOrder.fromJson(json);

  @override
  String get URL => "order/so/";

  @override
  List<String> get rolesRequired => ["sales_order"];

  String get allocate_url => "${url}allocate/";

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "reference": {},
      "customer": {
        "filters": {
          "is_customer": true,
        }
      },
      "customer_reference": {},
      "description": {},
      "project_code": {},
      "target_date": {},
      "link": {},
      "responsible": {},
      "contact": {
        "filters": {
          "company": customerId,
        }
      }
    };

    if (!InvenTreeAPI().supportsProjectCodes) {
      fields.remove("project_code");
    }

    if (!InvenTreeAPI().supportsContactModel) {
      fields.remove("contact");
    }

    return fields;
  }

  @override
  Map<String, String> defaultGetFilters() {
    return {
      "customer_detail": "true",
    };
  }

  @override
  Map<String, String> defaultListFilters() {
    return {
      "customer_detail": "true",
    };
  }

  int get customerId => getInt("customer");

  InvenTreeCompany? get customer {
    dynamic customer_detail = jsondata["customer_detail"];

    if (customer_detail == null) {
      return null;
    } else {
      return InvenTreeCompany.fromJson(customer_detail as Map<String, dynamic>);
    }
  }

  String get customerReference => getString("customer_reference");

  bool get isOpen => api.SalesOrderStatus.isNameIn(status, ["PENDING", "IN_PROGRESS"]);

  bool get isComplete => api.SalesOrderStatus.isNameIn(status, ["SHIPPED"]);

}


/*
 * Class representing an individual line item in a SalesOrder
 */
class InvenTreeSOLineItem extends InvenTreeOrderLine {

  InvenTreeSOLineItem() : super();

  InvenTreeSOLineItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeSOLineItem.fromJson(json);

  @override
  String get URL => "order/so-line/";

  @override
  List<String> get rolesRequired => ["sales_order"];

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "order": {
        "hidden": true,
      },
      "part": {
        "filters": {
          "salable": true,
        }
      },
      "quantity": {},
      "reference": {},
      "notes": {},
      "link": {},
    };
  }

  Map<String, Map<String, dynamic>> allocateFormFields() {

    return {
      "line_item": {
        "parent": "items",
        "nested": true,
        "hidden": true,
      },
      "stock_item": {
        "parent": "items",
        "nested": true,
        "filters": {},
      },
      "quantity": {
        "parent": "items",
        "nested": true,
      },
      "shipment": {
        "filters": {}
      }
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

  double get allocated => getDouble("allocated");

  bool get isAllocated => allocated >= quantity;

  double get allocatedRatio {
    if (quantity <= 0 || allocated <= 0) {
      return 0;
    }

    return allocated / quantity;
  }

  double get unallocatedQuantity {
    double unallocated = quantity - allocated;

    if (unallocated < 0) {
      unallocated = 0;
    }

    return unallocated;
  }

  String get allocatedString => simpleNumberString(allocated) + " / " + simpleNumberString(quantity);

  double get shipped => getDouble("shipped");

  double get outstanding => quantity - shipped;

  double get availableStock => getDouble("available_stock");

  double get progressRatio {
    if (quantity <= 0 || shipped <= 0) {
      return 0;
    }

    return shipped / quantity;
  }

  String get progressString => simpleNumberString(shipped) + " / " + simpleNumberString(quantity);

  bool get isComplete => shipped >= quantity;

  double get available => getDouble("available_stock") + getDouble("available_variant_stock");

  double get salePrice => getDouble("sale_price");

  String get salePriceCurrency => getString("sale_price_currency");

}


/*
 * Class representing a sales order shipment
 */
class InvenTreeSalesOrderShipment extends InvenTreeModel {

  InvenTreeSalesOrderShipment() : super();

  InvenTreeSalesOrderShipment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeSalesOrderShipment.fromJson(json);

  @override
  String get URL => "/order/so/shipment/";

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "order": {},
      "reference": {},
      "tracking_number": {},
      "invoice_number": {},
      "link": {},
    };

    return fields;
  }

  String get reference => getString("reference");

  String get tracking_number => getString("tracking_number");

  String get invoice_number => getString("invoice_number");

  String? get shipment_date => getString("shipment_date");

  bool get shipped => shipment_date != null && shipment_date!.isNotEmpty;
}



/*
 * Class representing an attachment file against a SalesOrder object
 */
class InvenTreeSalesOrderAttachment extends InvenTreeAttachment {

  InvenTreeSalesOrderAttachment() : super();

  InvenTreeSalesOrderAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeSalesOrderAttachment.fromJson(json);

  @override
  String get REFERENCE_FIELD => "order";

  @override
  String get URL => "order/so/attachment/";

}
