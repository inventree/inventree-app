/*
 * Models representing build orders
 */

import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/orders.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/widget/build/build_detail.dart";

/*
 * Class representing a Build Order
 */
class InvenTreeBuildOrder extends InvenTreeOrder {
  InvenTreeBuildOrder() : super();

  InvenTreeBuildOrder.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeBuildOrder.fromJson(json);

  // API endpoint URL
  @override
  String get URL => "build/";

  // Return the "reference field" for the attachment API
  String get REFERENCE_FIELD => "build";

  // Return the reference field for the modern attachment API
  String get REF_MODEL_TYPE => "build";

  @override
  List<String> get rolesRequired => ["build"];

  // Return icon for this model
  static IconData get icon => TablerIcons.hammer;

  // Part to be built
  int get partId => getInt("part");

  // Part detail information
  InvenTreePart? get partDetail {
    dynamic part_detail = jsondata["part_detail"];

    if (part_detail == null) {
      return null;
    } else {
      return InvenTreePart.fromJson(part_detail as Map<String, dynamic>);
    }
  }

  // Build quantity
  double get quantity => getDouble("quantity");

  // Completed quantity
  double get completed => getDouble("completed");

  // Progress as a percentage
  double get progressPercent {
    if (quantity <= 0) return 0.0;
    return (completed / quantity * 100).clamp(0.0, 100.0);
  }

  // Remaining quantity to be built
  double get remaining => quantity - completed;

  // Is the build order a parent build?
  bool get isParentBuild => getInt("parent") > 0;

  // Parent build ID
  int get parentBuildId => getInt("parent");

  // External build
  bool get external => getBool("external");

  // Return the location where the completed items will be stored
  int get destinationId => getInt("destination");

  String get destinationName => getString("name", subKey: "destination_detail");

  // Line item information
  @override
  int get lineItemCount => getInt("item_count", backup: 0);

  // Allocated line item count
  int get allocatedLineItemCount => getInt("allocated_line_count", backup: 0);

  // All line items are allocated
  bool get areAllLinesAllocated =>
      lineItemCount > 0 && lineItemCount == allocatedLineItemCount;

  // Output count
  int get outputCount => getInt("output_count", backup: 0);

  // Status code handling
  // Note: These map to BuildStatus in backend/status_codes.py
  bool get isWaitingForBuild => status == BuildOrderStatus.PENDING;
  bool get isInProgress => status == BuildOrderStatus.PRODUCTION;
  bool get isComplete => status == BuildOrderStatus.COMPLETE;
  bool get isCancelled => status == BuildOrderStatus.CANCELLED;
  bool get isOnHold => status == BuildOrderStatus.ON_HOLD;

  // Can this build order be completed?
  bool get canCompleteOrder {
    return isInProgress && outputCount > 0;
  }

  // Can this build order be issued?
  bool get canIssue {
    return isWaitingForBuild || isOnHold;
  }

  // Can this build order be put on hold?
  bool get canHold {
    return isWaitingForBuild || isInProgress;
  }

  // Can this build order be cancelled?
  bool get canCancel {
    return !isComplete && !isCancelled;
  }

  // Override form fields
  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "reference": {"required": true},
      "part": {"required": true},
      "title": {},
      "quantity": {"required": true},
      "priority": {},
      "parent": {},
      "sales_order": {},
      "batch": {},
      "target_date": {},
      "take_from": {},
      "destination": {},
      "project_code": {},
      "link": {},
      "external": {},
      "responsible": {},
      "notes": {},
    };
  }

  // Issue a build order
  Future<APIResponse> issue() async {
    return await InvenTreeAPI().post(
      "${URL}${pk}/issue/",
      body: {},
      expectedStatusCode: 201,
    );
  }

  // Complete a build order
  Future<APIResponse> completeOrder({
    bool acceptIncomplete = false,
    bool acceptUnallocated = false,
    bool acceptOverallocated = false,
  }) async {
    Map<String, String> data = {
      "accept_incomplete": acceptIncomplete.toString(),
      "accept_unallocated": acceptUnallocated.toString(),
      "accept_overallocated": acceptOverallocated.toString(),
    };

    return await InvenTreeAPI().post(
      "${URL}${pk}/complete/",
      body: data,
      expectedStatusCode: 201,
    );
  }

  // Put a build order on hold
  Future<APIResponse> hold() async {
    return await InvenTreeAPI().post(
      "${URL}${pk}/hold/",
      body: {},
      expectedStatusCode: 201,
    );
  }

  // Cancel a build order
  Future<APIResponse> cancel() async {
    return await InvenTreeAPI().post(
      "${URL}${pk}/cancel/",
      body: {},
      expectedStatusCode: 201,
    );
  }

  // Auto-allocate stock items for this build order
  Future<APIResponse> autoAllocate() async {
    return await InvenTreeAPI().post(
      "${URL}${pk}/auto-allocate/",
      body: {},
      expectedStatusCode: 201,
    );
  }

  // Unallocate all stock from this build order
  Future<APIResponse> unallocateAll() async {
    return await InvenTreeAPI().post(
      "${URL}${pk}/unallocate/",
      body: {},
      expectedStatusCode: 201,
    );
  }

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BuildOrderDetailWidget(this)),
    );
  }
}

/*
 * Class representing a build line
 */
class InvenTreeBuildLine extends InvenTreeOrderLine {
  InvenTreeBuildLine() : super();

  InvenTreeBuildLine.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeBuildLine.fromJson(json);

  // API endpoint URL
  @override
  String get URL => "build/line/";

  // Build order reference
  int get buildId => getInt("build");

  // BOM item reference
  int get bomItemId => getInt("bom_item");

  // Required quantity
  double get requiredQuantity => getDouble("quantity");

  // Allocated quantity
  double get allocatedQuantity => getDouble("allocated");

  // Reference the BOM item detail
  String get bomReference => getString("reference", subKey: "bom_item_detail");

  // Is this line fully allocated?
  bool get isFullyAllocated {
    // Allow for floating point comparison
    return allocatedQuantity >= (requiredQuantity - 0.0001);
  }

  // Is this line overallocated?
  bool get isOverallocated => allocatedQuantity > requiredQuantity;

  // Allocation progress as percentage
  double get progressPercent {
    if (requiredQuantity <= 0) return 0.0;
    return (allocatedQuantity / requiredQuantity * 100).clamp(0.0, 100.0);
  }
}

/*
 * Class representing a build item (stock allocation)
 */
class InvenTreeBuildItem extends InvenTreeModel {
  InvenTreeBuildItem() : super();

  InvenTreeBuildItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeBuildItem.fromJson(json);

  // API endpoint URL
  @override
  String get URL => "build/item/";

  // Build line reference
  int get buildLineId => getInt("build_line");

  // Stock item being allocated
  int get stockItemId => getInt("stock_item");

  // Quantity being allocated
  double get quantity => getDouble("quantity");

  // Stock item to install into
  int get installIntoId => getInt("install_into");

  // Stock item detail
  InvenTreeStockItem? get stockItem {
    dynamic stock_item = jsondata["stock_item_detail"];

    if (stock_item == null) {
      return null;
    } else {
      return InvenTreeStockItem.fromJson(stock_item as Map<String, dynamic>);
    }
  }

  // Allocation details
  String get locationName => getString("name", subKey: "location_detail");

  String get locationPath => getString("pathstring", subKey: "location_detail");

  String get serialNumber => getString("serial", subKey: "stock_item_detail");

  String get batchCode => getString("batch", subKey: "stock_item_detail");

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "build_line": {"required": true},
      "stock_item": {"required": true},
      "quantity": {"required": true},
      "install_into": {},
    };
  }
}

/*
 * Build Order Status Codes
 */
class BuildOrderStatus {
  // Status codes as defined in backend status_codes.py
  static const int PENDING = 10; // Build is pending / inactive
  static const int PRODUCTION = 20; // Build is active
  static const int CANCELLED = 30; // Build was cancelled
  static const int COMPLETE = 40; // Build is complete
  static const int ON_HOLD = 50; // Build is on hold

  // Return a color based on the build status
  static Color getStatusColor(int status) {
    switch (status) {
      case PENDING:
        return Colors.blue;
      case PRODUCTION:
        return Colors.green;
      case COMPLETE:
        return Colors.purple;
      case CANCELLED:
        return Colors.red;
      case ON_HOLD:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Return a string based on the build status
  static String getStatusText(int status) {
    switch (status) {
      case PENDING:
        return "Pending";
      case PRODUCTION:
        return "In Progress";
      case COMPLETE:
        return "Complete";
      case CANCELLED:
        return "Cancelled";
      case ON_HOLD:
        return "On Hold";
      default:
        return "Unknown";
    }
  }
}
