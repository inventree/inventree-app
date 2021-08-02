import 'model.dart';


/*
 * The InvenTreeCompany class repreents the Company model in the InvenTree database.
 */
class InvenTreeCompany extends InvenTreeModel {

  @override
  String NAME = "Company";

  @override
  String URL = "company/";

  InvenTreeCompany() : super();

  String get image => jsondata['image'] ?? '';

  String get website => jsondata['website'] ?? '';

  String get phone => jsondata['phone'] ?? '';

  String get email => jsondata['email'] ?? '';

  bool get isSupplier => jsondata['is_supplier'] ?? false;

  bool get isCustomer => jsondata['is_customer'] ?? false;

  InvenTreeCompany.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

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
  String url = "company/part/";

  @override
  Map<String, String> defaultListFilters() {
    return {
      "manufacturer_detail": "true",
      "supplier_detail": "true",
      "supplier_part_detail": "true",
    };
  }

  InvenTreeSupplierPart() : super();

  InvenTreeSupplierPart.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  int get manufacturerId => (jsondata['manufacturer'] ?? -1) as int;

  int get manufacturerPartId => (jsondata['manufacturer_part'] ?? -1) as int;

  int get supplierId => (jsondata['supplier'] ?? -1) as int;

  String get SKU => (jsondata['SKU'] ?? '') as String;

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

  InvenTreeManufacturerPart.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
  }

  int get partId => (jsondata['part'] ?? -1) as int;

  int get manufacturerId => (jsondata['manufacturer'] ?? -1) as int;

  String get MPN => (jsondata['MPN'] ?? '') as String;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var part = InvenTreeManufacturerPart.fromJson(json);

    return part;
  }
}
