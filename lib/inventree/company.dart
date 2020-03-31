import 'model.dart';


class InvenTreeCompany extends InvenTreeModel {
  @override
  String URL = "company/";

  InvenTreeCompany() : super();

  InvenTreeCompany.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var company = InvenTreeCompany.fromJson(json);

    return company;
  }
}