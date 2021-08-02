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

  InvenTreeSupplierPart() : super();

  InvenTreeSupplierPart.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var part = InvenTreeSupplierPart.fromJson(json);

    return part;
  }
}


class InvenTreeManufacturerPart extends InvenTreeModel {

  @override
  String url = "company/part/manufacturer/";

  InvenTreeManufacturerPart() : super();

  InvenTreeManufacturerPart.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var part = InvenTreeManufacturerPart.fromJson(json);

    return part;
  }
}
