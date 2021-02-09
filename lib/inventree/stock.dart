import 'dart:convert';

import 'package:InvenTree/inventree/part.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'model.dart';

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

  @override
  String NAME = "StockItem";

  @override
  String URL = "stock/";

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

    return headers;
  }

  InvenTreeStockItem() : super();

  InvenTreeStockItem.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  List<InvenTreePartTestTemplate> testTemplates = List<InvenTreePartTestTemplate>();

  int get testTemplateCount => testTemplates.length;

  // Get all the test templates associated with this StockItem
  Future<void> getTestTemplates(BuildContext context, {bool showDialog=false}) async {
    await InvenTreePartTestTemplate().list(
      context,
      filters: {
        "part": "${partId}",
      },
      dialog: showDialog,
    ).then((var templates) {
      testTemplates.clear();

      for (var t in templates) {
        if (t is InvenTreePartTestTemplate) {
          testTemplates.add(t);
        }
      }
    });
  }

  List<InvenTreeStockItemTestResult> testResults = List<InvenTreeStockItemTestResult>();

  int get testResultCount => testResults.length;

  Future<void> getTestResults(BuildContext context, {bool showDialog=false}) async {

    await InvenTreeStockItemTestResult().list(
      context,
      filters: {
        "stock_item": "${pk}",
        "user_detail": "true",
      },
      dialog: showDialog,
    ).then((var results) {
      testResults.clear();

      for (var r in results) {
        if (r is InvenTreeStockItemTestResult) {
          testResults.add(r);
        }
      }
    });
  }

  Future<bool> uploadTestResult(BuildContext context, String testName, bool result, {String value, String notes, File attachment}) async {

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
      var _result = await InvenTreeStockItemTestResult().create(context, data);

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

  int get partId => jsondata['part'] ?? -1;

  int get trackingItemCount => jsondata['tracking_items'] as int ?? 0;

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

    String thumb;

    if (jsondata.containsKey('part_detail')) {
      thumb = jsondata['part_detail']['thumbnail'] as String ?? '';
    }

    // Try a different approach
    if (thumb.isEmpty) {
      jsondata['part__thumbnail'] as String ?? '';
    }

    // Still no thumbnail? Use the 'no image' image
    if (thumb.isEmpty) thumb = InvenTreeAPI.staticThumb;

    return thumb;
  }

  int get supplierPartId => jsondata['supplier_part'] as int ?? -1;

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

  String get serialNumber => jsondata['serial'] as String ?? null;

  double get quantity => double.tryParse(jsondata['quantity'].toString() ?? '0');

  int get locationId => jsondata['location'] as int ?? -1;

  bool isSerialized() => serialNumber != null && quantity.toInt() == 1;

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

    if (serialNumber != null) {
      return "SN: $serialNumber";
    } else {
      return quantity.toString().trim();
    }
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var item = InvenTreeStockItem.fromJson(json);

    // TODO?

    return item;
  }

  Future<http.Response> countStock(double quan, {String notes}) async {

    // Cannot 'count' a serialized StockItem
    if (isSerialized()) {
      return null;
    }

    // Cannot count negative stock
    if (quan < 0) {
      return null;
    }

    return api.post("/stock/count/", body: {
      "item": {
        "pk": "${pk}",
        "quantity": "${quan}",
      },
      "notes": notes ?? '',
    });
  }

  Future<http.Response> addStock(double quan, {String notes}) async {

    if (isSerialized() || quan <= 0) return null;

    return api.post("/stock/add/", body: {
      "item": {
        "pk": "${pk}",
        "quantity": "${quan}",
      },
      "notes": notes ?? '',
    });
  }

  Future<http.Response> removeStock(double quan, {String notes}) async {

    if (isSerialized() || quan <= 0) return null;

    return api.post("/stock/remove/", body: {
      "item": {
        "pk": "${pk}",
        "quantity": "${quan}",
      },
      "notes": notes ?? '',
    });
  }

  Future<http.Response> transferStock(int location, {double quantity, String notes}) async {
    if (quantity == null) {} else
    if ((quantity < 0) || (quantity > this.quantity)) {
      quantity = this.quantity;
    }

    Map<String, dynamic> data = {
      "item": {
        "pk": "${pk}",
      },
      "location": "${location}",
      "notes": notes ?? '',
    };

    if (quantity != null) {
      data["item"]["quantity"] = "${quantity}";
    }

    return api.post("/stock/transfer/", body: data);
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