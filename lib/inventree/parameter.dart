import "package:inventree/inventree/model.dart";

class InvenTreeParameter extends InvenTreeModel {

  InvenTreeParameter() : super();

  InvenTreeParameter.fromJson(Map<String, dynamic> json)
      : super.fromJson(json);

  @override
  InvenTreeParameter createFromJson(Map<String, dynamic> json) => InvenTreeParameter.fromJson(json);

  @override
  String get URL => "parameter/";

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {"data": {}, "notes": {}};

    return fields;
  }

  // The model type of the instance this attachment is associated with
  String get modelType => getString("model_type");

  // The ID of the instance this attachment is associated with
  int get modelId => getInt("model_id");

  // Return a count of how many parameters exist against the specified model ID
  Future<int> countParameters(String modelType, int modelId) {
    Map<String, String> filters = {};

    filters["model_type"] = modelType;
    filters["model_id"] = modelId.toString();

    return count(filters: filters);
  }
}
