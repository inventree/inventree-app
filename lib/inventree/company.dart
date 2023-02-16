import "dart:async";

import "package:inventree/api.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/purchase_order.dart";


/*
 * The InvenTreeCompany class repreents the Company model in the InvenTree database.
 */

class InvenTreeCompany extends InvenTreeModel {

  InvenTreeCompany() : super();

  InvenTreeCompany.fromJson(Map<String, dynamic> json) : super.fromJson(json);

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

  String get image => (jsondata["image"] ?? jsondata["thumbnail"] ?? InvenTreeAPI.staticImage) as String;

  String get thumbnail => (jsondata["thumbnail"] ?? jsondata["image"] ?? InvenTreeAPI.staticThumb) as String;

  String get website => (jsondata["website"] ?? "") as String;

  String get phone => (jsondata["phone"] ?? "") as String;

  String get email => (jsondata["email"] ?? "") as String;

  bool get isSupplier => (jsondata["is_supplier"] ?? false) as bool;

  bool get isManufacturer => (jsondata["is_manufacturer"] ?? false)  as bool;

  bool get isCustomer => (jsondata["is_customer"] ?? false) as bool;

  int get partSuppliedCount => (jsondata["parts_supplied"] ?? 0) as int;

  int get partManufacturedCount => (jsondata["parts_manufactured"] ?? 0) as int;

  // Request a list of purchase orders against this company
  Future<List<InvenTreePurchaseOrder>> getPurchaseOrders({bool? outstanding}) async {

    Map<String, String> filters = {
      "supplier": "${pk}"
    };

    if (outstanding != null) {
      filters["outstanding"] = outstanding ? "true" : "false";
    }

    final List<InvenTreeModel> results = await InvenTreePurchaseOrder().list(
      filters: filters
    );

    List<InvenTreePurchaseOrder> orders = [];

    for (InvenTreeModel model in results) {
      if (model is InvenTreePurchaseOrder) {
        orders.add(model);
      }
    }

    return orders;
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var company = InvenTreeCompany.fromJson(json);

    return company;
  }
}


/*
 * Class representing an attachment file against a Company object
 */
class InvenTreeCompanyAttachment extends InvenTreeAttachment {

  InvenTreeCompanyAttachment() : super();

  InvenTreeCompanyAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get REFERENCE_FIELD => "company";

  @override
  String get URL => "company/attachment/";

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeCompanyAttachment.fromJson(json);

}

/*
 * The InvenTreeSupplierPart class represents the SupplierPart model in the InvenTree database
 */
class InvenTreeSupplierPart extends InvenTreeModel {

  InvenTreeSupplierPart() : super();

  InvenTreeSupplierPart.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "company/part/";

  @override
  Map<String, dynamic> formFields() {
    return {
      "supplier": {},
      "SKU": {},
      "link": {},
      "note": {},
      "packaging": {},
      "pack_size": {},
    };
  }

  Map<String, String> _filters() {
    return {
      "manufacturer_detail": "true",
      "supplier_detail": "true",
      "part_detail": "true",
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

  String get manufacturerName => (jsondata["manufacturer_detail"]?["name"] ?? "") as String;

  String get MPN => (jsondata["manufacturer_part_detail"]?["MPN"] ?? "") as String;

  String get manufacturerImage => (jsondata["manufacturer_detail"]?["image"] ?? jsondata["manufacturer_detail"]["thumbnail"] ?? InvenTreeAPI.staticThumb) as String;

  int get manufacturerPartId => (jsondata["manufacturer_part"] ?? -1) as int;

  int get supplierId => (jsondata["supplier"] ?? -1) as int;

  String get supplierName => (jsondata["supplier_detail"]?["name"] ?? "") as String;

  String get supplierImage => (jsondata["supplier_detail"]?["image"] ?? jsondata["supplier_detail"]["thumbnail"] ?? InvenTreeAPI.staticThumb) as String;

  String get SKU => (jsondata["SKU"] ?? "") as String;

  int get partId => (jsondata["part"] ?? -1) as int;

  String get partImage => (jsondata["part_detail"]?["thumbnail"] ?? InvenTreeAPI.staticThumb) as String;

  String get partName => (jsondata["part_detail"]?["full_name"] ?? "") as String;

  String get partDescription => (jsondata["part_detail"]?["description"] ?? "") as String;

  String get note => (jsondata["note"] ?? "") as String;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var part = InvenTreeSupplierPart.fromJson(json);

    return part;
  }
}


class InvenTreeManufacturerPart extends InvenTreeModel {

  InvenTreeManufacturerPart() : super();

  InvenTreeManufacturerPart.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String url = "company/part/manufacturer/";

  @override
  Map<String, String> defaultListFilters() {
    return {
      "manufacturer_detail": "true",
    };
  }

  int get partId => (jsondata["part"] ?? -1) as int;

  int get manufacturerId => (jsondata["manufacturer"] ?? -1) as int;

  String get MPN => (jsondata["MPN"] ?? "") as String;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var part = InvenTreeManufacturerPart.fromJson(json);

    return part;
  }
}
