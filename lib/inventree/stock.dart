import "dart:async";

import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/stock/stock_detail.dart";

/*
 * Class representing a test result for a single stock item
 */
class InvenTreeStockItemTestResult extends InvenTreeModel {
  InvenTreeStockItemTestResult() : super();

  InvenTreeStockItemTestResult.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  String get URL => "stock/test/";

  @override
  List<String> get rolesRequired => ["stock"];

  @override
  Map<String, String> defaultFilters() {
    return {"user_detail": "true", "template_detail": "true"};
  }

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "stock_item": {"hidden": true},
      "test": {},
      "template": {
        "filters": {"enabled": "true"},
      },
      "result": {},
      "value": {},
      "notes": {},
      "attachment": {},
    };

    if (InvenTreeAPI().supportsModernTestResults) {
      fields.remove("test");
    } else {
      fields.remove("template");
    }

    return fields;
  }

  String get key => getString("key");

  int get templateId => getInt("template");

  String get testName => getString("test");

  bool get result => getBool("result");

  String get value => getString("value");

  String get attachment => getString("attachment");

  String get username => getString("username", subKey: "user_detail");

  String get date => getString("date");

  @override
  InvenTreeStockItemTestResult createFromJson(Map<String, dynamic> json) {
    var result = InvenTreeStockItemTestResult.fromJson(json);
    return result;
  }
}

class InvenTreeStockItemHistory extends InvenTreeModel {
  InvenTreeStockItemHistory() : super();

  InvenTreeStockItemHistory.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeStockItemHistory.fromJson(json);

  @override
  String get URL => "stock/track/";

  @override
  Map<String, String> defaultFilters() {
    // By default, order by decreasing date
    return {"ordering": "-date", "user_detail": "true"};
  }

  DateTime? get date => getDate("date");

  String get dateString => getDateString("date");

  String get label => getString("label");

  // Return the "deltas" associated with this historical object
  Map<String, dynamic> get deltas => getMap("deltas");

  // Return the quantity string for this historical object
  String get quantityString {
    var _deltas = deltas;

    if (_deltas.containsKey("quantity")) {
      double q = double.tryParse(_deltas["quantity"].toString()) ?? 0;

      return simpleNumberString(q);
    } else {
      return "";
    }
  }

  int? get user => getValue("user") as int?;

  String get userString {
    if (user != null) {
      return getString("username", subKey: "user_detail");
    } else {
      return "";
    }
  }
}

/*
 * Class representing a StockItem database instance
 */
class InvenTreeStockItem extends InvenTreeModel {
  InvenTreeStockItem() : super();

  InvenTreeStockItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "stock/";

  static const String MODEL_TYPE = "stockitem";

  @override
  List<String> get rolesRequired => ["stock"];

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StockDetailWidget(this)),
    );
  }

  // Return a set of fields to transfer this stock item via dialog
  Map<String, dynamic> transferFields() {
    Map<String, dynamic> fields = {
      "pk": {"parent": "items", "nested": true, "hidden": true, "value": pk},
      "quantity": {"parent": "items", "nested": true, "value": quantity},
      "location": {"value": locationId},
      "status": {"parent": "items", "nested": true, "value": status},
      "packaging": {"parent": "items", "nested": true, "value": packaging},
      "notes": {},
    };

    if (isSerialized()) {
      // Prevent editing of 'quantity' field if the item is serialized
      fields["quantity"]?["hidden"] = true;
    }

    // Old API does not support these fields
    if (!api.supportsStockAdjustExtraFields) {
      fields.remove("packaging");
      fields.remove("status");
    }

    return fields;
  }

  // URLs for performing stock actions
  static String transferStockUrl() => "stock/transfer/";

  static String countStockUrl() => "stock/count/";

  static String addStockUrl() => "stock/add/";

  static String removeStockUrl() => "stock/remove/";

  @override
  String get WEB_URL => "stock/item/";

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "part": {},
      "location": {},
      "quantity": {},
      "serial": {},
      "serial_numbers": {"label": L10().serialNumbers, "type": "string"},
      "status": {},
      "batch": {},
      "purchase_price": {},
      "purchase_price_currency": {},
      "packaging": {},
      "link": {},
    };

    return fields;
  }

  @override
  Map<String, String> defaultFilters() {
    return {
      "part_detail": "true",
      "location_detail": "true",
      "supplier_detail": "true",
      "supplier_part_detail": "true",
      "cascade": "false",
    };
  }

  List<InvenTreePartTestTemplate> testTemplates = [];

  int get testTemplateCount => testTemplates.length;

  // Get all the test templates associated with this StockItem
  Future<void> getTestTemplates({bool showDialog = false}) async {
    await InvenTreePartTestTemplate()
        .list(filters: {"part": "${partId}", "enabled": "true"})
        .then((var templates) {
          testTemplates.clear();

          for (var t in templates) {
            if (t is InvenTreePartTestTemplate) {
              testTemplates.add(t);
            }
          }
        });
  }

  List<InvenTreeStockItemTestResult> testResults = [];

  int get testResultCount => testResults.length;

  Future<void> getTestResults() async {
    await InvenTreeStockItemTestResult()
        .list(filters: {"stock_item": "${pk}", "user_detail": "true"})
        .then((var results) {
          testResults.clear();

          for (var r in results) {
            if (r is InvenTreeStockItemTestResult) {
              testResults.add(r);
            }
          }
        });
  }

  bool get isInStock => getBool("in_stock", backup: true);

  String get packaging => getString("packaging");

  String get batch => getString("batch");

  int get partId => getInt("part");

  double? get purchasePrice {
    String pp = getString("purchase_price");

    if (pp.isEmpty) {
      return null;
    } else {
      return double.tryParse(pp);
    }
  }

  String get purchasePriceCurrency => getString("purchase_price_currency");

  bool get hasPurchasePrice {
    double? pp = purchasePrice;
    return pp != null && pp > 0;
  }

  int get purchaseOrderId => getInt("purchase_order");

  int get trackingItemCount => getInt("tracking_items", backup: 0);

  bool get isBuilding => getBool("is_building");

  int get salesOrderId => getInt("sales_order");

  bool get hasSalesOrder => salesOrderId > 0;

  int get customerId => getInt("customer");

  bool get hasCustomer => customerId > 0;

  bool get stale => getBool("stale");

  bool get expired => getBool("expired");

  DateTime? get expiryDate => getDate("expiry_date");

  String get expiryDateString => getDateString("expiry_date");

  // Date of last update
  DateTime? get updatedDate => getDate("updated");

  String get updatedDateString => getDateString("updated");

  DateTime? get stocktakeDate => getDate("stocktake_date");

  String get stocktakeDateString => getDateString("stocktake_date");

  String get partName {
    String nm = "";

    // Use the detailed part information as priority
    if (jsondata.containsKey("part_detail")) {
      nm = (jsondata["part_detail"]?["full_name"] ?? "") as String;
    }

    // Backup if first value fails
    if (nm.isEmpty) {
      nm = getString("part__name");
    }

    return nm;
  }

  String get partDescription {
    String desc = "";

    // Use the detailed part description as priority
    if (jsondata.containsKey("part_detail")) {
      desc = (jsondata["part_detail"]?["description"] ?? "") as String;
    }

    if (desc.isEmpty) {
      desc = getString("part__description");
    }

    return desc;
  }

  String get partImage {
    String img = "";

    if (jsondata.containsKey("part_detail")) {
      img = (jsondata["part_detail"]?["thumbnail"] ?? "") as String;
    }

    if (img.isEmpty) {
      img = getString("part__thumbnail");
    }

    return img;
  }

  /*
   * Return the Part thumbnail for this stock item.
   */
  String get partThumbnail {
    String thumb = "";

    thumb = (jsondata["part_detail"]?["thumbnail"] ?? "") as String;

    // Use "image" as a backup
    if (thumb.isEmpty) {
      thumb = (jsondata["part_detail"]?["image"] ?? "") as String;
    }

    // Try a different approach
    if (thumb.isEmpty) {
      thumb = getString("part__thumbnail");
    }

    // Still no thumbnail? Use the "no image" image
    if (thumb.isEmpty) thumb = InvenTreeAPI.staticThumb;

    return thumb;
  }

  int get supplierPartId => getInt("supplier_part");

  String get supplierImage {
    String thumb = "";

    if (jsondata.containsKey("supplier_part_detail")) {
      thumb =
          (jsondata["supplier_part_detail"]?["supplier_detail"]?["image"] ?? "")
              as String;
    } else if (jsondata.containsKey("supplier_detail")) {
      thumb = (jsondata["supplier_detail"]?["image"] ?? "") as String;
    }

    return thumb;
  }

  String get supplierName =>
      getString("supplier_name", subKey: "supplier_detail");

  String get units => getString("units", subKey: "part_detail");

  String get supplierSKU => getString("SKU", subKey: "supplier_part_detail");

  String get serialNumber => getString("serial");

  double get quantity => getDouble("quantity");

  String quantityString({bool includeUnits = true}) {
    String q = "";

    if (allocated > 0) {
      q += simpleNumberString(available);
      q += " / ";
    }

    q += simpleNumberString(quantity);

    if (includeUnits && units.isNotEmpty) {
      q += " ${units}";
    }

    return q;
  }

  double get allocated => getDouble("allocated");

  double get available => quantity - allocated;

  int get locationId => getInt("location");

  bool isSerialized() => serialNumber.isNotEmpty && quantity.toInt() == 1;

  String serialOrQuantityDisplay() {
    if (isSerialized()) {
      return "SN ${serialNumber}";
    } else if (allocated > 0) {
      return "${available} / ${quantity}";
    } else {
      return simpleNumberString(quantity);
    }
  }

  String get locationName {
    if (locationId == -1 || !jsondata.containsKey("location_detail")) {
      return "Unknown Location";
    }

    String loc = getString("name", subKey: "location_detail");

    // Old-style name
    if (loc.isEmpty) {
      loc = getString("location__name");
    }

    return loc;
  }

  String get locationPathString {
    if (locationId == -1 || !jsondata.containsKey("location_detail")) {
      return L10().locationNotSet;
    }

    String _loc = getString("pathstring", subKey: "location_detail");
    if (_loc.isNotEmpty) {
      return _loc;
    } else {
      return locationName;
    }
  }

  String get displayQuantity {
    // Display either quantity or serial number!

    if (serialNumber.isNotEmpty) {
      return "SN: $serialNumber";
    } else {
      String q = simpleNumberString(quantity);

      if (units.isNotEmpty) {
        q += " ${units}";
      }

      return q;
    }
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeStockItem.fromJson(json);

  /*
   * Perform stocktake action:
   *
   * - Add
   * - Remove
   * - Count
   */
  Future<bool> adjustStock(
    String endpoint,
    double q, {
    String? notes,
    int? location,
  }) async {
    // Serialized stock cannot be adjusted (unless it is a "transfer")
    if (isSerialized() && location == null) {
      return false;
    }

    // Cannot handle negative stock
    if (q < 0) {
      return false;
    }

    Map<String, dynamic> data = {};

    data = {
      "items": [
        {"pk": "${pk}", "quantity": "${quantity}"},
      ],
      "notes": notes ?? "",
    };

    if (location != null) {
      data["location"] = location;
    }

    var response = await api.post(endpoint, body: data);

    return response.isValid() &&
        (response.statusCode == 200 || response.statusCode == 201);
  }

  Future<bool> countStock(double q, {String? notes}) async {
    final bool result = await adjustStock("/stock/count/", q, notes: notes);

    return result;
  }

  Future<bool> addStock(double q, {String? notes}) async {
    final bool result = await adjustStock("/stock/add/", q, notes: notes);

    return result;
  }

  Future<bool> removeStock(double q, {String? notes}) async {
    final bool result = await adjustStock("/stock/remove/", q, notes: notes);

    return result;
  }

  Future<bool> transferStock(
    int location, {
    double? quantity,
    String? notes,
  }) async {
    double q = this.quantity;

    if (quantity != null) {
      q = quantity;
    }

    final bool result = await adjustStock(
      "/stock/transfer/",
      q,
      notes: notes,
      location: location,
    );

    return result;
  }
}

class InvenTreeStockLocation extends InvenTreeModel {
  InvenTreeStockLocation() : super();

  InvenTreeStockLocation.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  String get URL => "stock/location/";

  static const String MODEL_TYPE = "stocklocation";

  @override
  List<String> get rolesRequired => ["stock"];

  String get pathstring => getString("pathstring");

  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationDisplayWidget(this)),
    );
  }

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "name": {},
      "description": {},
      "parent": {},
      "structural": {},
    };

    return fields;
  }

  String get parentPathString {
    List<String> psplit = pathstring.split("/");

    if (psplit.isNotEmpty) {
      psplit.removeLast();
    }

    String p = psplit.join("/");

    if (p.isEmpty) {
      p = "Top level stock location";
    }

    return p;
  }

  int get itemcount => (jsondata["items"] ?? 0) as int;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreeStockLocation.fromJson(json);
}
