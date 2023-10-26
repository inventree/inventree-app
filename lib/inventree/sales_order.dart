

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

  // TODO: Order status interpretation

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
    // TODO: Return set of form fields
    return {};
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

  double get shipped => getDouble("shipped");

  double get outstanding => quantity - shipped;

  String get progressString => simpleNumberString(shipped) + " / " + simpleNumberString(quantity);

  bool get isComplete => shipped >= quantity;

  double get available => getDouble("available_stock") + getDouble("available_variant_stock");

  double get salePrice => getDouble("sale_price");

  String get salePriceCurrency => getString("sale_price_currency");

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
  String get URL => "order/po/attachment/";

}
