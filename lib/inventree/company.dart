import 'package:inventree/api.dart';

import 'model.dart';


/*
 * The InvenTreeCompany class repreents the Company model in the InvenTree database.
 */

class InvenTreeCompany extends InvenTreeModel {

  @override
  String get URL => "company/";

  @override
  Map<String, dynamic> formFields() {
    return {
      "name": {},
      "description": {},
      "website": {},
      "is_supplier": {},
      "is_manufacturer": {},
      "is_customer": {},
      "currency": {},
    };
  }

  InvenTreeCompany() : super();

  String get image => (jsondata['image'] ?? jsondata['thumbnail'] ?? InvenTreeAPI.staticImage) as String;

  String get thumbnail => (jsondata['thumbnail'] ?? jsondata['image'] ?? InvenTreeAPI.staticThumb) as String;

  String get website => (jsondata['website'] ?? '') as String;

  String get phone => (jsondata['phone'] ?? '') as String;

  String get email => (jsondata['email'] ?? '') as String;

  bool get isSupplier => (jsondata['is_supplier'] ?? false) as bool;

  bool get isManufacturer => (jsondata['is_manufacturer'] ?? false)  as bool;

  bool get isCustomer => (jsondata['is_customer'] ?? false) as bool;

  InvenTreeCompany.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var company = InvenTreeCompany.fromJson(json);

    return company;
  }
}


/*
 * The InvenTreeSupplierPart class represents the SupplierPart model in the InvenTree database
 */
class InvenTreeSupplierPart extends InvenTreeModel {
  @override
  String get URL => "company/part/";

  Map<String, String> _filters() {
    return {
      "manufacturer_detail": "true",
      "supplier_detail": "true",
      "manufacturer_part_detail": "true",
    };
  }

  @override
  Map<String, String> defaultListFilters() {
    return _filters();
  }

  @override
  Map<String, String> defaultGetFilters() {
    return _filters();
  }

  InvenTreeSupplierPart() : super();

  InvenTreeSupplierPart.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  int get manufacturerId => (jsondata['manufacturer'] ?? -1) as int;

  String get manufacturerName => (jsondata['manufacturer_detail']['name'] ?? '') as String;

  String get manufacturerImage => (jsondata['manufacturer_detail']['image'] ?? jsondata['manufacturer_detail']['thumbnail'] ?? InvenTreeAPI.staticThumb) as String;

  int get manufacturerPartId => (jsondata['manufacturer_part'] ?? -1) as int;

  int get supplierId => (jsondata['supplier'] ?? -1) as int;

  String get supplierName => (jsondata['supplier_detail']['name'] ?? '') as String;

  String get supplierImage => (jsondata['supplier_detail']['image'] ?? jsondata['supplier_detail']['thumbnail'] ?? InvenTreeAPI.staticThumb) as String;

  String get SKU => (jsondata['SKU'] ?? '') as String;

  String get MPN => (jsondata['MPN'] ?? '') as String;

  int get partId => (jsondata['part'] ?? -1) as int;

  String get partImage => (jsondata["part_detail"]["thumbnail"] ?? InvenTreeAPI.staticThumb) as String;

  String get partName => (jsondata["part_detail"]["full_name"] ?? '') as String;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var part = InvenTreeSupplierPart.fromJson(json);

    return part;
  }
}


class InvenTreeManufacturerPart extends InvenTreeModel {

  @override
  String url = "company/part/manufacturer/";

  @override
  Map<String, String> defaultListFilters() {
    return {
      "manufacturer_detail": "true",
    };
  }

  InvenTreeManufacturerPart() : super();

  InvenTreeManufacturerPart.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  int get partId => (jsondata['part'] ?? -1) as int;

  int get manufacturerId => (jsondata['manufacturer'] ?? -1) as int;

  String get MPN => (jsondata['MPN'] ?? '') as String;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var part = InvenTreeManufacturerPart.fromJson(json);

    return part;
  }
}
