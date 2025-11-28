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
    Map<String, Map<String, dynamic>> fields = {
      "header": {
        "type": "string",
        "read_only": true,
        "label": name,
        "help_text": description,
        "value": "",
      },
      "data": {
        "type": "string",
      },
      "note": {}
    };

    return fields;
  }

  @override
  String get name => getString("name", subKey: "template_detail");

  @override
  String get description => getString("description", subKey: "template_detail");

  String get value => getString("data");

  String get valueString {
    String v = value;

    if (units.isNotEmpty) {
      v += " ";
      v += units;
    }

    return v;
  }

  bool get as_bool => value.toLowerCase() == "true";

  String get units => getString("units", subKey: "template_detail");

  bool get is_checkbox =>
      getBool("checkbox", subKey: "template_detail", backup: false);

  // The model type of the instance this attachment is associated with
  String get modelType => getString("model_type");

  // The ID of the instance this attachment is associated with
  int get modelId => getInt("model_id");

  // Return a count of how many parameters exist against the specified model ID
  Future<int> countParameters(String modelType, int modelId) async {
    Map<String, String> filters = {};

    if (!api.supportsModernParameters) {
      return 0;
    }

    filters["model_type"] = modelType;
    filters["model_id"] = modelId.toString();

    return count(filters: filters);
  }
}
