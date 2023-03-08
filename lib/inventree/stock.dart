import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/part.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/l10.dart";

import "package:inventree/api.dart";


class InvenTreeStockItemTestResult extends InvenTreeModel {

  InvenTreeStockItemTestResult() : super();

  InvenTreeStockItemTestResult.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "stock/test/";

  @override
  Map<String, dynamic> formFields() {
    return {
      "stock_item": {
        "hidden": true
      },
      "test": {},
      "result": {},
      "value": {},
      "notes": {},
      "attachment": {},
    };
  }

  String get key => (jsondata["key"] ?? "") as String;

  String get testName => (jsondata["test"] ?? "") as String;

  bool get result => (jsondata["result"] ?? false) as bool;

  String get value => (jsondata["value"] ?? "") as String;

  String get attachment => (jsondata["attachment"] ?? "") as String;

  String get date => (jsondata["date"] ?? "") as String;

  @override
  InvenTreeStockItemTestResult createFromJson(Map<String, dynamic> json) {
    var result = InvenTreeStockItemTestResult.fromJson(json);
    return result;
  }

}


class InvenTreeStockItemHistory extends InvenTreeModel {

  InvenTreeStockItemHistory() : super();

  InvenTreeStockItemHistory.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreeStockItemHistory.fromJson(json);
  }

  @override
  String get URL => "stock/track/";

  @override
  Map<String, String> defaultListFilters() {

    // By default, order by decreasing date
    return {
      "ordering": "-date",
    };
  }

  DateTime? get date {
    if (jsondata.containsKey("date")) {
      return DateTime.tryParse((jsondata["date"] ?? "") as String);
    } else {
      return null;
    }
  }

  String get dateString {
    var d = date;

    if (d == null) {
      return "";
    }

    return DateFormat("yyyy-MM-dd").format(d);
  }

  String get label => (jsondata["label"] ?? "") as String;

  String get quantityString {
    Map<String, dynamic> deltas = (jsondata["deltas"] ?? {}) as Map<String, dynamic>;

    // Serial number takes priority here
    if (deltas.containsKey("serial")) {
      var serial = (deltas["serial"] ?? "").toString();
      return "# ${serial}";
    } else if (deltas.containsKey("quantity")) {
      double q = (deltas["quantity"] ?? 0) as double;

      return simpleNumberString(q);
    } else {
      return "";
    }
  }
}


class InvenTreeStockItem extends InvenTreeModel {

  InvenTreeStockItem() : super();

  InvenTreeStockItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  // Stock status codes
  static const int OK = 10;
  static const int ATTENTION = 50;
  static const int DAMAGED = 55;
  static const int DESTROYED = 60;
  static const int REJECTED = 65;
  static const int LOST = 70;
  static const int QUARANTINED = 75;
  static const int RETURNED = 85;

  String statusLabel() {

    // TODO: Delete me - The translated status values should be provided by the API!

    switch (status) {
      case OK:
        return L10().ok;
      case ATTENTION:
        return L10().attention;
      case DAMAGED:
        return L10().damaged;
      case DESTROYED:
        return L10().destroyed;
      case REJECTED:
        return L10().rejected;
      case LOST:
        return L10().lost;
      case QUARANTINED:
        return L10().quarantined;
      case RETURNED:
        return L10().returned;
      default:
        return status.toString();
    }
  }

  // Return color associated with stock status
  Color get statusColor {
    switch (status) {
      case OK:
        return Colors.black;
      case ATTENTION:
        return Color(0xFFfdc82a);
      case DAMAGED:
      case DESTROYED:
      case REJECTED:
        return Color(0xFFe35a57);
      case QUARANTINED:
        return Color(0xFF0DCAF0);
      case LOST:
      default:
        return Color(0xFFAAAAAA);
    }
  }

  @override
  String get URL => "stock/";

  // URLs for performing stock actions

  static String transferStockUrl() => "stock/transfer/";

  static String countStockUrl() => "stock/count/";

  static String addStockUrl() => "stock/add/";

  static String removeStockUrl() => "stock/remove/";

  @override
  String get WEB_URL => "stock/item/";

  @override
  Map<String, dynamic> formFields() {
    return {
      "part": {},
      "location": {},
      "quantity": {},
      "serial": {},
      "serial_numbers": {
        "label": L10().serialNumber,
        "type": "string",
      },
      "status": {},
      "batch": {},
      "purchase_price": {},
      "purchase_price_currency": {},
      "packaging": {},
      "link": {},
    };
  }

  @override
  Map<String, String> defaultGetFilters() {

    return {
      "part_detail": "true",
      "location_detail": "true",
      "supplier_detail": "true",
      "cascade": "false"
    };
  }

  @override
  Map<String, String> defaultListFilters() {

    return {
      "part_detail": "true",
      "location_detail": "true",
      "supplier_detail": "true",
      "in_stock": "true",
    };
  }

  List<InvenTreePartTestTemplate> testTemplates = [];

  int get testTemplateCount => testTemplates.length;

  // Get all the test templates associated with this StockItem
  Future<void> getTestTemplates({bool showDialog=false}) async {
    await InvenTreePartTestTemplate().list(
      filters: {
        "part": "${partId}",
      },
    ).then((var templates) {
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

    await InvenTreeStockItemTestResult().list(
      filters: {
        "stock_item": "${pk}",
        "user_detail": "true",
      },
    ).then((var results) {
      testResults.clear();

      for (var r in results) {
        if (r is InvenTreeStockItemTestResult) {
          testResults.add(r);
        }
      }
    });
  }

  int get status => (jsondata["status"] ?? -1) as int;

  String get packaging => (jsondata["packaging"] ?? "") as String;

  String get batch => (jsondata["batch"] ?? "") as String;

  int get partId => (jsondata["part"] ?? -1) as int;
  
  double? get purchasePrice {
    String pp = (jsondata["purchase_price"] ?? "") as String;

    if (pp.isEmpty) {
      return null;
    } else {
      return double.tryParse(pp);
    }
  }

  String get purchasePriceCurrency => (jsondata["purchase_price_currency"] ?? "") as String;

  bool get hasPurchasePrice {
    double? pp = purchasePrice;
    return pp != null && pp > 0;
  }

  int get purchaseOrderId => (jsondata["purchase_order"] ?? -1) as int;

  int get trackingItemCount => (jsondata["tracking_items"] ?? 0) as int;

  bool get isBuilding => (jsondata["is_building"] ?? false) as bool;

    // Date of last update
    DateTime? get updatedDate {
      if (jsondata.containsKey("updated")) {
        return DateTime.tryParse((jsondata["updated"] ?? "") as String);
      } else {
        return null;
      }
    }

    String get updatedDateString {
      var _updated = updatedDate;

      if (_updated == null) {
        return "";
      }

      final DateFormat _format = DateFormat("yyyy-MM-dd");

      return _format.format(_updated);
    }

    DateTime? get stocktakeDate {
      if (jsondata.containsKey("stocktake_date")) {
        return DateTime.tryParse((jsondata["stocktake_date"] ?? "") as String);
      } else {
        return null;
      }
    }

    String get stocktakeDateString {
      var _stocktake = stocktakeDate;

      if (_stocktake == null) {
        return "";
      }

      final DateFormat _format = DateFormat("yyyy-MM-dd");

      return _format.format(_stocktake);
    }

    String get partName {

      String nm = "";

      // Use the detailed part information as priority
      if (jsondata.containsKey("part_detail")) {
        nm = (jsondata["part_detail"]["full_name"] ?? "") as String;
      }

      // Backup if first value fails
      if (nm.isEmpty) {
        nm = (jsondata["part__name"] ?? "") as String;
      }

      return nm;
    }

    String get partDescription {
      String desc = "";

      // Use the detailed part description as priority
      if (jsondata.containsKey("part_detail")) {
        desc = (jsondata["part_detail"]["description"] ?? "") as String;
      }

      if (desc.isEmpty) {
        desc = (jsondata["part__description"] ?? "") as String;
      }

      return desc;
    }

    String get partImage {
      String img = "";

      if (jsondata.containsKey("part_detail")) {
        img = (jsondata["part_detail"]["thumbnail"] ?? "") as String;
      }

      if (img.isEmpty) {
        img = (jsondata["part__thumbnail"] ?? "") as String;
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
        thumb = (jsondata["part__thumbnail"] ?? "") as String;
      }

      // Still no thumbnail? Use the "no image" image
      if (thumb.isEmpty) thumb = InvenTreeAPI.staticThumb;

      return thumb;
    }

    int get supplierPartId => (jsondata["supplier_part"] ?? -1) as int;

    String get supplierImage {
      String thumb = "";

      if (jsondata.containsKey("supplier_part_detail")) {
        thumb = (jsondata["supplier_part_detail"]?["supplier_detail"]?["image"] ?? "") as String;
      } else if (jsondata.containsKey("supplier_detail")) {
        thumb = (jsondata["supplier_detail"]["image"] ?? "") as String;
      }

      return thumb;
    }

    String get supplierName {
      String sname = "";

      if (jsondata.containsKey("supplier_detail")) {
        sname = (jsondata["supplier_detail"]["supplier_name"] ?? "") as String;
      }

      return sname;
    }

    String get units {
      return (jsondata["part_detail"]?["units"] ?? "") as String;
    }

    String get supplierSKU {
      String sku = "";

      if (jsondata.containsKey("supplier_part_detail")) {
        sku = (jsondata["supplier_part_detail"]["SKU"] ?? "") as String;
      }

      return sku;
    }

    String get serialNumber => (jsondata["serial"] ?? "") as String;

    double get quantity => double.tryParse(jsondata["quantity"].toString()) ?? 0;

    String quantityString({bool includeUnits = false}){

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

    double get allocated => double.tryParse(jsondata["allocated"].toString()) ?? 0;

    double get available => quantity - allocated;

    int get locationId => (jsondata["location"] ?? -1) as int;

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
      String loc = "";

      if (locationId == -1 || !jsondata.containsKey("location_detail")) return "Unknown Location";

      loc = (jsondata["location_detail"]["name"] ?? "") as String;

      // Old-style name
      if (loc.isEmpty) {
        loc = (jsondata["location__name"] ?? "") as String;
      }

      return loc;
    }

    String get locationPathString {

      if (locationId == -1 || !jsondata.containsKey("location_detail")) return L10().locationNotSet;

      String _loc = (jsondata["location_detail"]["pathstring"] ?? "") as String;

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
        return simpleNumberString(quantity);
      }
    }

    @override
    InvenTreeModel createFromJson(Map<String, dynamic> json) {
      return InvenTreeStockItem.fromJson(json);
    }

    /*
   * Perform stocktake action:
   *
   * - Add
   * - Remove
   * - Count
   */
    Future<bool> adjustStock(String endpoint, double q, {String? notes, int? location}) async {

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
          {
            "pk": "${pk}",
            "quantity": "${quantity}",
          }
        ],
        "notes": notes ?? "",
      };

      if (location != null) {
        data["location"] = location;
      }

      var response = await api.post(
        endpoint,
        body: data,
      );

      return response.isValid() && (response.statusCode == 200 || response.statusCode == 201);
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

    Future<bool> transferStock(int location, {double? quantity, String? notes}) async {

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


/*
 * Class representing an attachment file against a StockItem object
 */
class InvenTreeStockItemAttachment extends InvenTreeAttachment {

  InvenTreeStockItemAttachment() : super();

  InvenTreeStockItemAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get REFERENCE_FIELD => "stock_item";

  @override
  String get URL => "stock/attachment/";

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreeStockItemAttachment.fromJson(json);
  }

}


class InvenTreeStockLocation extends InvenTreeModel {

  InvenTreeStockLocation() : super();

  InvenTreeStockLocation.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "stock/location/";

  String get pathstring => (jsondata["pathstring"] ?? "") as String;

  @override
  Map<String, dynamic> formFields() {
    Map<String, dynamic> fields = {
      "name": {},
      "description": {},
      "parent": {},
      "structural": {},
    };

    if (!api.supportsStructuralCategories) {
      fields.remove("structural");
    }

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
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

    var loc = InvenTreeStockLocation.fromJson(json);

    return loc;
  }
}