import 'dart:convert';

import 'model.dart';

import 'package:InvenTree/api.dart';

class InvenTreeStockItem extends InvenTreeModel {
  @override
  String URL = "stock/";

  @override
  Map<String, String> defaultGetFilters() {

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

  int get partId => jsondata['part'] ?? -1;

  int get trackingItemCount => jsondata['tracking_items'] as int ?? 0;

  String get partName {

    String nm = '';

    // Use the detailed part information as priority
    if (jsondata.containsKey('part_detail')) {
      nm = jsondata['part_detail']['full_name'] ?? '';
    }

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

  String get partThumbnail {
    String thumb = jsondata['part__thumbnail'] as String ?? '';

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

  int get serialNumber => jsondata['serial'] as int ?? null;

  double get quantity => double.tryParse(jsondata['quantity'].toString() ?? '0');

  int get locationId => jsondata['location'] as int ?? -1;

  String get locationName {
    String loc = '';

    if (jsondata.containsKey('location_detail')) {
      loc = jsondata['location_detail']['name'] ?? '';
    }

    if (loc.isEmpty) {
      loc = jsondata['location__name'] ?? '';
    }

    return loc;
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
}


class InvenTreeStockLocation extends InvenTreeModel {
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