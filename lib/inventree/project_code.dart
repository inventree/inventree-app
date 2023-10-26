import "package:inventree/inventree/model.dart";


/*
 * Class representing the ProjectCode database model
 */
class InvenTreeProjectCode extends InvenTreeModel {

  InvenTreeProjectCode() : super();

  InvenTreeProjectCode.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeProjectCode.fromJson(json);

  @override
  String get URL => "project-code/";

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "code": {},
      "description": {},
    };
  }

  String get code => getString("code");
}
