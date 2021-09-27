import 'package:intl/intl.dart';
import 'package:inventree/inventree/part.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'model.dart';
import 'package:inventree/l10.dart';


import 'dart:async';
import 'dart:io';

import 'package:inventree/api.dart';


class InvenTreeStockItemTestResult extends InvenTreeModel {

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

  String get key => jsondata['key'] ?? '';

  String get testName => jsondata['test'] ?? '';

  bool get result => jsondata['result'] ?? false;

  String get value => jsondata['value'] ?? '';

  String get notes => jsondata['notes'] ?? '';

  String get attachment => jsondata['attachment'] ?? '';

  String get date => jsondata['date'] ?? '';

  InvenTreeStockItemTestResult() : super();

  InvenTreeStockItemTestResult.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeStockItemTestResult createFromJson(Map<String, dynamic> json) {
    var result = InvenTreeStockItemTestResult.fromJson(json);
    return result;
  }

}


class InvenTreeStockItem extends InvenTreeModel {

  // Stock status codes
  static const int OK = 10;
  static const int ATTENTION = 50;
  static const int DAMAGED = 55;
  static const int DESTROYED = 60;
  static const int REJECTED = 65;
  static const int LOST = 70;
  static const int RETURNED = 85;

  String statusLabel(BuildContext context) {

    // TODO: Delete me - The translated status values are provided by the API!

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
        return Color(0xFF50aa51);
      case ATTENTION:
        return Color(0xFFfdc82a);
      case DAMAGED:
      case DESTROYED:
      case REJECTED:
        return Color(0xFFe35a57);
      case LOST:
      default:
        return Color(0xFFAAAAAA);
    }
  }

  @override
  String get URL => "stock/";

  @override
  String WEB_URL = "stock/item/";

  @override
  Map<String, dynamic> formFields() {
    return {
      "part": {},
      "location": {},
      "quantity": {},
      "status": {},
      "batch": {},
      "packaging": {},
      "link": {},
    };
  }

  @override
  Map<String, String> defaultGetFilters() {

    var headers = new Map<String, String>();

    headers["part_detail"] = "true";
    headers["location_detail"] = "true";
    headers["supplier_detail"] = "true";
    headers["cascade"] = "false";

    return headers;
  }

  @override
  Map<String, String> defaultListFilters() {

    var headers = new Map<String, String>();

    headers["part_detail"] = "true";
    headers["location_detail"] = "true";
    headers["supplier_detail"] = "true";
    headers["cascade"] = "false";

    return headers;
  }

  InvenTreeStockItem() : super();

  InvenTreeStockItem.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
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

  String get uid => jsondata['uid'] ?? '';

  int get status => jsondata['status'] ?? -1;

  String get packaging => jsondata["packaging"] ?? "";

  String get batch => jsondata["batch"] ?? "";

  int get partId => jsondata['part'] ?? -1;
  
  String get purchasePrice => jsondata['purchase_price'] ?? "";

  bool get hasPurchasePrice {

    String pp = purchasePrice;

    return pp.isNotEmpty && pp.trim() != "-";
  }

  int get trackingItemCount => (jsondata['tracking_items'] ?? 0) as int;

  // Date of last update
  DateTime? get updatedDate {
    if (jsondata.containsKey("updated")) {
      return DateTime.tryParse(jsondata["updated"] ?? '');
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
      return DateTime.tryParse(jsondata["stocktake_date"] ?? '');
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

    String nm = '';

    // Use the detailed part information as priority
    if (jsondata.containsKey('part_detail')) {
      nm = jsondata['part_detail']['full_name'] ?? '';
    }

    // Backup if first value fails
    if (nm.isEmpty) {
      nm = jsondata['part__name'] ?? '';
    }

    return nm;
  }

  String get partDescription {
    String desc = '';

    // Use the detailed part description as priority
    if (jsondata.containsKey('part_detail')) {
      desc = jsondata['part_detail']['description'] ?? '';
    }

    if (desc.isEmpty) {
      desc = jsondata['part__description'] ?? '';
    }

    return desc;
  }

  String get partImage {
    String img = '';

    if (jsondata.containsKey('part_detail')) {
      img = jsondata['part_detail']['thumbnail'] ?? '';
    }

    if (img.isEmpty) {
      img = jsondata['part__thumbnail'] ?? '';
    }

    return img;
  }

  /*
   * Return the Part thumbnail for this stock item.
   */
  String get partThumbnail {

    String thumb = "";

    thumb = jsondata['part_detail']?['thumbnail'] ?? '';

    // Use 'image' as a backup
    if (thumb.isEmpty) {
      thumb = jsondata['part_detail']?['image'] ?? '';
    }

    // Try a different approach
    if (thumb.isEmpty) {
      thumb = jsondata['part__thumbnail'] ?? '';
    }

    // Still no thumbnail? Use the 'no image' image
    if (thumb.isEmpty) thumb = InvenTreeAPI.staticThumb;

    return thumb;
  }

  int get supplierPartId => (jsondata['supplier_part'] ?? -1) as int;

  String get supplierImage {
    String thumb = '';

    if (jsondata.containsKey("supplier_detail")) {
      thumb = jsondata['supplier_detail']['supplier_logo'] ?? '';
    }

    return thumb;
  }

  String get supplierName {
    String sname = '';

    if (jsondata.containsKey("supplier_detail")) {
      sname = jsondata["supplier_detail"]["supplier_name"] ?? '';
    }

    return sname;
  }

  String get units {
    return jsondata['part_detail']?['units'] ?? '';
  }

  String get supplierSKU {
    String sku = '';

    if (jsondata.containsKey("supplier_detail")) {
      sku = jsondata["supplier_detail"]["SKU"] ?? '';
    }

    return sku;
  }

  String get serialNumber => jsondata['serial'] ?? "";

  double get quantity => double.tryParse(jsondata['quantity'].toString()) ?? 0;

  String get quantityString {

    String q = quantity.toString();

    // Simplify integer values e.g. "1.0" becomes "1"
    if (quantity.toInt() == quantity) {
      q = quantity.toInt().toString();
    }

    if (units.isNotEmpty) {
      q += " ${units}";
    }

    return q;
  }

  int get locationId => (jsondata['location'] ?? -1) as int;

  bool isSerialized() => serialNumber.isNotEmpty && quantity.toInt() == 1;

  String serialOrQuantityDisplay() {
    if (isSerialized()) {
      return 'SN ${serialNumber}';
    }

    // Is an integer?
    if (quantity.toInt() == quantity) {
      return '${quantity.toInt()}';
    }

    return '${quantity}';
  }

  String get locationName {
    String loc = '';

    if (locationId == -1 || !jsondata.containsKey('location_detail')) return 'Unknown Location';

    loc = jsondata['location_detail']['name'] ?? '';

    // Old-style name
    if (loc.isEmpty) {
      loc = jsondata['location__name'] ?? '';
    }

    return loc;
  }

  String get locationPathString {

    if (locationId == -1 || !jsondata.containsKey('location_detail')) return L10().locationNotSet;

    String _loc = jsondata['location_detail']['pathstring'] ?? '';

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
      return quantityString;
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
  Future<bool> adjustStock(BuildContext context, String endpoint, double q, {String? notes}) async {

    // Serialized stock cannot be adjusted
    if (isSerialized()) {
      return false;
    }

    // Cannot handle negative stock
    if (q < 0) {
      return false;
    }

    print("Adjust stock: ${endpoint}");

    var response = await api.post(
      endpoint,
      body: {
        "item": {
        "pk": "${pk}",
        "quantity": "${q}",
        },
        "notes": notes ?? '',
      },
      expectedStatusCode: 200
    );

    return response.isValid();
  }

  Future<bool> countStock(BuildContext context, double q, {String? notes}) async {

    final bool result = await adjustStock(context, "/stock/count/", q, notes: notes);

    return result;
  }

  Future<bool> addStock(BuildContext context, double q, {String? notes}) async {

    final bool result = await adjustStock(context,  "/stock/add/", q, notes: notes);

    return result;
  }

  Future<bool> removeStock(BuildContext context, double q, {String? notes}) async {

    final bool result = await adjustStock(context, "/stock/remove/", q, notes: notes);

    return result;
  }

  Future<bool> transferStock(int location, {double? quantity, String? notes}) async {
    if ((quantity == null) || (quantity < 0) || (quantity > this.quantity)) {
      quantity = this.quantity;
    }

    final response = await api.post(
      "/stock/transfer/",
      body: {
        "item": {
          "pk": "${pk}",
          "quantity": "${quantity}",
        },
        "location": "${location}",
        "notes": notes ?? "",
      },
      expectedStatusCode: 200
    );

    return response.isValid() && response.statusCode == 200;
  }
}


class InvenTreeStockLocation extends InvenTreeModel {

  @override
  String get URL => "stock/location/";

  String get pathstring => jsondata['pathstring'] ?? '';

  @override
  Map<String, dynamic> formFields() {
    return {
      "name": {},
      "description": {},
      "parent": {},
    };
  }

  String get parentpathstring {
    // TODO - Drive the refactor tractor through this
    List<String> psplit = pathstring.split('/');

    if (psplit.length > 0) {
      psplit.removeLast();
    }

    String p = psplit.join('/');

    if (p.isEmpty) {
      p = "Top level stock location";
    }

    return p;
  }

  int get itemcount => jsondata['items'] ?? 0;

  InvenTreeStockLocation() : super();

  InvenTreeStockLocation.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

    var loc = InvenTreeStockLocation.fromJson(json);

    return loc;
  }
}