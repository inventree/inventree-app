/*
 * Models representing transfer orders
 */

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/orders.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/order/transfer_order_detail.dart";

/*
 * Class representing an individual TransferOrder instance
 */
class InvenTreeTransferOrder extends InvenTreeOrder {
  InvenTreeTransferOrder() : super();

  InvenTreeTransferOrder.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeTransferOrder.fromJson(json);

  // API endpoint URL
  @override
  String get URL => "order/transfer-order/";

  static const String MODEL_TYPE = "transferorder";

  @override
  List<String> get rolesRequired => ["transfer_order"];

  // Return icon for this model
  static IconData get icon => TablerIcons.transfer;

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TransferOrderDetailWidget(this)),
    );
  }

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "reference": {},
      "description": {},
      "project_code": {},
      "take_from": {},
      "destination": {"required": true},
      "consume": {},
      "start_date": {},
      "target_date": {},
      "link": {},
      "responsible": {},
    };
  }

  @override
  Map<String, String> defaultFilters() {
    return {"take_from_detail": "true", "destination_detail": "true"};
  }

  // Source location for this transfer order (may be null - any location)
  int? get sourceLocationId {
    int value = getInt("take_from");
    return value > 0 ? value : null;
  }

  // Destination location for this transfer order
  int? get destinationId {
    int value = getInt("destination");
    return value > 0 ? value : null;
  }

  // Should allocated stock be "consumed" rather than transferred?
  bool get consume => getBool("consume");

  bool get isPending => TransferOrderStatus.isNameIn(status, ["PENDING"]);

  bool get isIssued => TransferOrderStatus.isNameIn(status, ["ISSUED"]);

  bool get isOnHold => TransferOrderStatus.isNameIn(status, ["ON_HOLD"]);

  bool get isComplete => TransferOrderStatus.isNameIn(status, ["COMPLETE"]);

  bool get isCancelled => TransferOrderStatus.isNameIn(status, ["CANCELLED"]);

  // An "open" order is one which is not complete or cancelled
  bool get isOpen => !isComplete && !isCancelled;

  // Can this order be issued?
  bool get canIssue => isPending || isOnHold;

  // Can this order be placed on hold?
  bool get canHold => isPending || isIssued;

  // Can this order be completed?
  bool get canCompleteOrder => (isIssued || isOnHold) && !isPending;

  // Can this order be cancelled?
  bool get canCancel => isOpen;

  Future<List<InvenTreeTransferOrderLineItem>> getLineItems() async {
    final results = await InvenTreeTransferOrderLineItem().list(
      filters: {"order": "${pk}"},
    );

    List<InvenTreeTransferOrderLineItem> items = [];

    for (var result in results) {
      if (result is InvenTreeTransferOrderLineItem) {
        items.add(result);
      }
    }

    return items;
  }

  /// Mark this order as "issued"
  Future<APIResponse> issue() async {
    return await api.post(
      "${URL}${pk}/issue/",
      body: {},
      expectedStatusCode: 201,
    );
  }

  /// Place this order on hold
  Future<APIResponse> hold() async {
    return await api.post(
      "${URL}${pk}/hold/",
      body: {},
      expectedStatusCode: 201,
    );
  }

  /// Mark this order as "complete"
  Future<APIResponse> completeOrder({bool acceptIncomplete = false}) async {
    Map<String, String> data = {
      "accept_incomplete": acceptIncomplete.toString(),
    };

    return await api.post(
      "${URL}${pk}/complete/",
      body: data,
      expectedStatusCode: 201,
    );
  }

  /// Mark this order as "cancelled"
  Future<APIResponse> cancel() async {
    return await api.post(
      "${URL}${pk}/cancel/",
      body: {},
      expectedStatusCode: 201,
    );
  }
}

/*
 * Class representing a line item within a Transfer Order
 */
class InvenTreeTransferOrderLineItem extends InvenTreeOrderLine {
  InvenTreeTransferOrderLineItem() : super();

  InvenTreeTransferOrderLineItem.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeTransferOrderLineItem.fromJson(json);

  // API endpoint URL
  @override
  String get URL => "order/transfer-order-line/";

  @override
  List<String> get rolesRequired => ["transfer_order"];

  @override
  Map<String, String> defaultFilters() {
    return {"part_detail": "true", "order_detail": "true"};
  }

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "order": {
        // Cannot edit the order from here
        "hidden": true,
      },
      "part": {
        "required": true,
        "filters": {"virtual": false},
      },
      "quantity": {"required": true},
      "reference": {},
      "target_date": {},
      "link": {},
      "notes": {},
    };
  }

  // Quantity of stock allocated against this line item
  double get allocated => getDouble("allocated");

  // Quantity of stock which has actually been transferred
  double get transferred => getDouble("transferred");

  bool get isComplete => transferred >= quantity;

  double get outstanding => quantity - transferred;

  double get progressRatio {
    if (quantity <= 0 || transferred <= 0) {
      return 0;
    }

    return transferred / quantity;
  }

  String get progressString =>
      simpleNumberString(transferred) + " / " + simpleNumberString(quantity);

  InvenTreeTransferOrder? get transferOrder {
    dynamic detail = jsondata["order_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreeTransferOrder.fromJson(detail as Map<String, dynamic>);
    }
  }
}

/*
 * Class representing a single stock allocation against a Transfer Order line item
 */
class InvenTreeTransferOrderAllocation extends InvenTreeModel {
  InvenTreeTransferOrderAllocation() : super();

  InvenTreeTransferOrderAllocation.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeTransferOrderAllocation.fromJson(json);

  @override
  String get URL => "order/transfer-order-allocation/";

  static const String MODEL_TYPE = "transferorderallocation";

  @override
  List<String> get rolesRequired => ["transfer_order"];

  @override
  Map<String, String> defaultFilters() {
    return {
      "part_detail": "true",
      "order_detail": "true",
      "item_detail": "true",
      "location_detail": "true",
    };
  }

  double get quantity => getDouble("quantity");

  int get lineId => getInt("line");

  int get orderId => getInt("order");

  InvenTreeTransferOrder? get order {
    dynamic detail = jsondata["order_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreeTransferOrder.fromJson(detail as Map<String, dynamic>);
    }
  }

  int get stockItemId => getInt("item");

  InvenTreeStockItem? get stockItem {
    dynamic detail = jsondata["item_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreeStockItem.fromJson(detail as Map<String, dynamic>);
    }
  }

  int get partId => getInt("part");

  InvenTreePart? get part {
    dynamic detail = jsondata["part_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreePart.fromJson(detail as Map<String, dynamic>);
    }
  }

  int get locationId => getInt("location");

  InvenTreeStockLocation? get location {
    dynamic detail = jsondata["location_detail"];

    if (detail == null) {
      return null;
    } else {
      return InvenTreeStockLocation.fromJson(detail as Map<String, dynamic>);
    }
  }
}

/*
 * Transfer Order Status Codes
 * Ref: https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/order/status_codes.py
 */
class TransferOrderStatus {
  // Status codes as defined in backend status_codes.py
  static const int PENDING = 10; // Transfer order is pending / inactive
  static const int ISSUED = 20; // Transfer order has been issued
  static const int ON_HOLD = 25; // Transfer order is on hold
  static const int COMPLETE = 30; // Transfer order is complete
  static const int CANCELLED = 40; // Transfer order was cancelled

  static const Map<int, String> _names = {
    PENDING: "PENDING",
    ISSUED: "ISSUED",
    ON_HOLD: "ON_HOLD",
    COMPLETE: "COMPLETE",
    CANCELLED: "CANCELLED",
  };

  // Return the (untranslated) name associated with a given status code
  static String name(int status) => _names[status] ?? "";

  // Test if the name associated with the given code is in the provided list
  static bool isNameIn(int status, List<String> names) {
    return names.contains(name(status));
  }

  // Return a color based on the transfer order status
  static Color getStatusColor(int status) {
    switch (status) {
      case PENDING:
        return COLOR_GRAY_LIGHT;
      case ISSUED:
        return COLOR_PROGRESS;
      case COMPLETE:
        return COLOR_SUCCESS;
      case CANCELLED:
        return COLOR_DANGER;
      case ON_HOLD:
        return COLOR_WARNING;
      default:
        return COLOR_GRAY_LIGHT;
    }
  }

  // Return a (translated) string based on the transfer order status
  static String getStatusText(int status) {
    switch (status) {
      case PENDING:
        return L10().pending;
      case ISSUED:
        return L10().issued;
      case COMPLETE:
        return L10().complete;
      case CANCELLED:
        return L10().cancelled;
      case ON_HOLD:
        return L10().onHold;
      default:
        return L10().unknown;
    }
  }
}
