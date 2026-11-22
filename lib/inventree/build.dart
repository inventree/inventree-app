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

/// Result of a build order action which may run as a background task
enum BuildTaskOutcome { complete, queued, failed }

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

  static const String MODEL_TYPE = "build";

  @override
  List<String> get rolesRequired => ["build"];

  // Return icon for this model
  static IconData get icon => TablerIcons.hammer;

  @override
  String get description => getString("title");

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

  // Return the location where the items will be sourced from (null if not set)
  int? get sourceLocationId {
    final int id = getInt("take_from");
    return id > 0 ? id : null;
  }

  // Return the location where the completed items will be stored (null if not set)
  int? get destinationId {
    final int id = getInt("destination");
    return id > 0 ? id : null;
  }

  // Note: The server's BuildSerializer does not provide line or output counts.
  // These are queried separately (see BuildOrderDetailWidget).

  // Status code handling
  // Note: These map to BuildStatus in backend/status_codes.py
  bool get isWaitingForBuild =>
      api.BuildOrderStatus.isNameIn(logicalStatus, ["PENDING"]);
  bool get isInProgress =>
      api.BuildOrderStatus.isNameIn(logicalStatus, ["PRODUCTION"]);
  bool get isComplete =>
      api.BuildOrderStatus.isNameIn(logicalStatus, ["COMPLETE"]);
  bool get isCancelled =>
      api.BuildOrderStatus.isNameIn(logicalStatus, ["CANCELLED"]);
  bool get isOnHold =>
      api.BuildOrderStatus.isNameIn(logicalStatus, ["ON_HOLD"]);

  // Can this build order be completed?
  // Matches the server web UI: offered for any in-production build,
  // and the server validates the rest (incomplete outputs, child builds, etc)
  bool get canCompleteOrder => isInProgress;

  // API endpoint for marking this build order as complete
  String get finishUrl => "${URL}${pk}/finish/";

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
      "start_date": {},
      "target_date": {},
      "take_from": {},
      "destination": {},
      "project_code": {},
      "link": {},
      "external": {},
      "responsible": {},
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
  // The status code is checked by the caller (see autoAllocateOutcome)
  Future<APIResponse> autoAllocate() async {
    return await InvenTreeAPI().post(
      "${URL}${pk}/auto-allocate/",
      body: {},
      expectedStatusCode: null,
    );
  }

  /*
   * Interpret the response from the auto-allocate endpoint:
   * - API < 465: returns 201 once allocation has completed
   * - API >= 465: returns task details (200) - the task is either
   *   offloaded to the background worker, or run synchronously
   */
  static BuildTaskOutcome autoAllocateOutcome(APIResponse response) {
    if (response.statusCode == 201) {
      return BuildTaskOutcome.complete;
    }

    if (response.statusCode != 200) {
      return BuildTaskOutcome.failed;
    }

    final Map<String, dynamic> data = response.asMap();

    if (data["complete"] == true) {
      return data["success"] == true
          ? BuildTaskOutcome.complete
          : BuildTaskOutcome.failed;
    }

    return BuildTaskOutcome.queued;
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

  @override
  Map<String, String> defaultFilters() {
    return {"part_detail": "true"};
  }

  @override
  List<String> get rolesRequired => ["build"];

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

  @override
  Map<String, String> defaultFilters() {
    return {
      "part_detail": "true",
      "stock_detail": "true",
      "location_detail": "true",
    };
  }

  @override
  List<String> get rolesRequired => ["build"];

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

  // Part details
  String get partName => getString("name", subKey: "part_detail");

  String get partDescription => getString("description", subKey: "part_detail");

  String get partThumbnail => getString("thumbnail", subKey: "part_detail");

  // Allocation details
  String get locationName => getString("name", subKey: "location_detail");

  String get locationPath => getString("pathstring", subKey: "location_detail");

  String get serialNumber => getString("serial", subKey: "stock_item_detail");

  String get batchCode => getString("batch", subKey: "stock_item_detail");

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "build_line": {"required": true, "hidden": true},
      "stock_item": {"required": true},
      "quantity": {"required": true},
      "install_into": {"hidden": true},
    };
  }
}
