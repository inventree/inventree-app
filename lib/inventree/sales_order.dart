import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:inventree/helpers.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/orders.dart";
import "package:inventree/widget/order/so_shipment_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/order/extra_line_detail.dart";
import "package:inventree/widget/order/sales_order_detail.dart";

/*
 * Class representing an individual SalesOrder
 */
class InvenTreeSalesOrder extends InvenTreeOrder {
  InvenTreeSalesOrder() : super();

  InvenTreeSalesOrder.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeSalesOrder.fromJson(json);

  @override
  String get URL => "order/so/";

  static const String MODEL_TYPE = "salesorder";

  @override
  List<String> get rolesRequired => ["sales_order"];

  String get allocate_url => "${url}allocate/";

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SalesOrderDetailWidget(this)),
    );
  }

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "reference": {},
      "customer": {
        "filters": {"is_customer": true},
      },
      "customer_reference": {},
      "description": {},
      "project_code": {},
      "start_date": {},
      "target_date": {},
      "link": {},
      "responsible": {},
      "contact": {
        "filters": {"company": customerId},
      },
    };

    if (!InvenTreeAPI().supportsProjectCodes) {
      fields.remove("project_code");
    }

    if (!InvenTreeAPI().supportsContactModel) {
      fields.remove("contact");
    }

    if (!InvenTreeAPI().supportsStartDate) {
      fields.remove("start_date");
    }

    return fields;
  }

  @override
  Map<String, String> defaultFilters() {
    return {"customer_detail": "true"};
  }

  Future<void> issueOrder() async {
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

  bool get isOpen => api.SalesOrderStatus.isNameIn(status, [
    "PENDING",
    "IN_PROGRESS",
    "ON_HOLD",
  ]);

  bool get isPending =>
      api.SalesOrderStatus.isNameIn(status, ["PENDING", "ON_HOLD"]);

  bool get isInProgress =>
      api.SalesOrderStatus.isNameIn(status, ["IN_PROGRESS"]);

  bool get isComplete => api.SalesOrderStatus.isNameIn(status, ["SHIPPED"]);
}

/*
 * Class representing an individual line item in a SalesOrder
 */
class InvenTreeSOLineItem extends InvenTreeOrderLine {
  InvenTreeSOLineItem() : super();

  InvenTreeSOLineItem.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeSOLineItem.fromJson(json);

  @override
  String get URL => "order/so-line/";

  @override
  List<String> get rolesRequired => ["sales_order"];

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "order": {"hidden": true},
      "part": {
        "filters": {"salable": true},
      },
      "quantity": {},
      "reference": {},
      "notes": {},
      "link": {},
    };
  }

  Map<String, Map<String, dynamic>> allocateFormFields() {
    return {
      "line_item": {"parent": "items", "nested": true, "hidden": true},
      "stock_item": {"parent": "items", "nested": true, "filters": {}},
      "quantity": {"parent": "items", "nested": true},
      "shipment": {"filters": {}},
    };
  }

  @override
  Map<String, String> defaultFilters() {
    return {"part_detail": "true"};
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

  String get allocatedString =>
      simpleNumberString(allocated) + " / " + simpleNumberString(quantity);

  double get shipped => getDouble("shipped");

  double get outstanding => quantity - shipped;

  double get availableStock => getDouble("available_stock");

  double get progressRatio {
    if (quantity <= 0 || shipped <= 0) {
      return 0;
    }

    return shipped / quantity;
  }

  String get progressString =>
      simpleNumberString(shipped) + " / " + simpleNumberString(quantity);

  bool get isComplete => shipped >= quantity;

  double get available =>
      getDouble("available_stock") + getDouble("available_variant_stock");

  double get salePrice => getDouble("sale_price");

  String get salePriceCurrency => getString("sale_price_currency");
}

class InvenTreeSOExtraLineItem extends InvenTreeExtraLineItem {
  InvenTreeSOExtraLineItem() : super();

  InvenTreeSOExtraLineItem.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeSOExtraLineItem.fromJson(json);

  @override
  String get URL => "order/so-extra-line/";

  @override
  List<String> get rolesRequired => ["sales_order"];

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ExtraLineDetailWidget(this)),
    );
  }
}

/*
 * Class representing a sales order shipment
 */
class InvenTreeSalesOrderShipment extends InvenTreeModel {
  InvenTreeSalesOrderShipment() : super();

  InvenTreeSalesOrderShipment.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeSalesOrderShipment.fromJson(json);

  @override
  String get URL => "/order/so/shipment/";

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SOShipmentDetailWidget(this)),
    );
  }

  @override
  List<String> get rolesRequired => ["sales_order"];

  static const String MODEL_TYPE = "salesordershipment";

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

  int get orderId => getInt("order");

  String get reference => getString("reference");

  String get tracking_number => getString("tracking_number");

  String get invoice_number => getString("invoice_number");

  String? get shipment_date => getString("shipment_date");

  String? get delivery_date => getString("delivery_date");

  int? get checked_by_id => getInt("checked_by");

  bool get isChecked => checked_by_id != null && checked_by_id! > 0;

  bool get isShipped => shipment_date != null && shipment_date!.isNotEmpty;

  bool get isDelivered => delivery_date != null && delivery_date!.isNotEmpty;
}

/*
 * Class representing an attachment file against a SalesOrder object
 */
class InvenTreeSalesOrderAttachment extends InvenTreeAttachment {
  InvenTreeSalesOrderAttachment() : super();

  InvenTreeSalesOrderAttachment.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeSalesOrderAttachment.fromJson(json);

  @override
  String get REFERENCE_FIELD => "order";

  @override
  String get REF_MODEL_TYPE => "salesorder";

  @override
  String get URL => InvenTreeAPI().supportsModernAttachments
      ? "attachment/"
      : "order/so/attachment/";
}


class InvenTreeSalesOrderShipmentAttachment extends InvenTreeAttachment {
  InvenTreeSalesOrderShipmentAttachment() : super();

  InvenTreeSalesOrderShipmentAttachment.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeSalesOrderShipmentAttachment.fromJson(json);

  @override
  String get REFERENCE_FIELD => "shipment";

  @override
  String get REF_MODEL_TYPE => "salesordershipment";

  @override
  String get URL => "attachment/";
}