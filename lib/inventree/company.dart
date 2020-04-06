import 'model.dart';


/*
 * The InvenTreeCompany class repreents the Company model in the InvenTree database.
 */
class InvenTreeCompany extends InvenTreeModel {
  @override
  String URL = "company/";

  InvenTreeCompany() : super();

  String get image => jsondata['image'] ?? '';

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