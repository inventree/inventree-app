import 'package:InvenTree/inventree/part.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'model.dart';
import 'package:InvenTree/l10.dart';


import 'dart:async';
import 'dart:io';

import 'package:InvenTree/api.dart';


class InvenTreeStockItemTestResult extends InvenTreeModel {

  @override
  String NAME = "StockItemTestResult";

  @override
  String URL = "stock/test/";

  String get key => jsondata['key'] ?? '';

  String get testName => jsondata['test'] ?? '';

  bool get result => jsondata['result'] ?? false;

  String get value => jsondata['value'] ?? '';

  String get notes => jsondata['notes'] ?? '';

  String get attachment => jsondata['attachment'] ?? '';

  String get date => jsondata['date'] ?? '';

  InvenTreeStockItemTestResult() : super();

  InvenTreeStockItemTestResult.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
  }

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
  String NAME = "StockItem";

  @override
  String URL = "stock/";

  @override
  String WEB_URL = "stock/item/";

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

  Future<bool> uploadTestResult(BuildContext context, String testName, bool result, {String? value, String? notes, File? attachment}) async {

    Map<String, String> data = {
      "stock_item": pk.toString(),
      "test": testName,
      "result": result.toString(),
    };

    if (value != null && !value.isEmpty) {
      data["value"] = value;
    }

    if (notes != null && !notes.isEmpty) {
      data["notes"] = notes;
    }

    /*
     * Upload is performed in different ways, depending if an attachment is provided.
     * TODO: Is there a nice way to refactor this one?
     */
    if (attachment == null) {
      var _result = await InvenTreeStockItemTestResult().create(data);

      return (_result != null) && (_result is InvenTreeStockItemTestResult);
    } else {
      var url = InvenTreeStockItemTestResult().URL;
      http.StreamedResponse _uploadResponse = await InvenTreeAPI().uploadFile(url, attachment, fields: data);

      // Check that the HTTP status code is HTTP_201_CREATED
      return _uploadResponse.statusCode == 201;
    }

    return false;
  }

  String get uid => jsondata['uid'] ?? '';

  int get status => jsondata['status'] ?? -1;

  int get partId => jsondata['part'] ?? -1;

  int get trackingItemCount => (jsondata['tracking_items'] ?? 0) as int;

  // Date of last update
  String get updated => jsondata["updated"] ?? "";

  DateTime? get stocktakeDate {
    if (jsondata.containsKey("stocktake_date")) {
      if (jsondata["stocktake_date"] == null) {
        return null;
      }

      return DateTime.tryParse(jsondata["stocktake_date"]) ?? null;
    } else {
      return null;
    }
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

  /**
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

    if (quantity.toInt() == quantity) {
      return quantity.toInt().toString();
    } else {
      return quantity.toString();
    }
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
    String path = '';

    if (locationId == -1 || !jsondata.containsKey('location_detail')) return 'No location specified';

    return jsondata['location_detail']['pathstring'] ?? '';
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
    var item = InvenTreeStockItem.fromJson(json);

    // TODO?

    return item;
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

    print("Adjustment completed!");

    if (response == null) {
      return false;
    }

    // Stock adjustment succeeded!
    return true;
  }

  Future<bool> countStock(BuildContext context, double q, {String? notes}) async {

    final bool result = await adjustStock(context, "/stock/count", q, notes: notes);

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

    return response != null;
  }
}


class InvenTreeStockLocation extends InvenTreeModel {

  @override
  String NAME = "StockLocation";

  @override
  String URL = "stock/location/";

  String get pathstring => jsondata['pathstring'] ?? '';

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

  InvenTreeStockLocation.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

    var loc = InvenTreeStockLocation.fromJson(json);

    return loc;
  }
}