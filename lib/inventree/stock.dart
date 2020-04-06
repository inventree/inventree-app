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

    return headers;
  }

  InvenTreeStockItem() : super();

  InvenTreeStockItem.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  String get partName => jsondata['part__name'] as String ?? '';

  String get partDescription => jsondata['part__description'] as String ?? '';

  String get partThumbnail {
    String thumb = jsondata['part__thumbnail'] as String ?? '';

    if (thumb.isEmpty) thumb = InvenTreeAPI.staticThumb;

    return thumb;
  }

  int get serialNumber => jsondata['serial'] as int ?? null;

  double get quantity => jsondata['quantity'] as double ?? 0.0;

  int get locationId => jsondata['location'] as int ?? -1;

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

  @override
  bool matchAgainstString(String filter) {

    if (name.toLowerCase().contains(filter)) return true;

    if (description.toLowerCase().contains(filter)) return true;

    return false;
  }
}