import 'dart:convert';

import 'package:InvenTree/api.dart';


/*
 * Class that represents a single "form field",
 * defined by the InvenTree API
 */
class APIFormField {

  // Constructor
  APIFormField(this.name, this.data);

  // Name of this field
  final String name;

  // JSON data which defines the field
  final dynamic data;

  // Is this field hidden?
  bool get hidden => (data['hidden'] ?? false) as bool;

  // Is this field read only?
  bool get readOnly => (data['read_only'] ?? false) as bool;

  // Is this field required?
  bool get required => (data['required'] ?? false) as bool;

  String get label => (data['label'] ?? '') as String;

  String get helpText => (data['help_text'] ?? '') as String;

}


/*
 * Extract field options from a returned OPTIONS request
 */
Map<String, dynamic> extractFields(dynamic options) {

  if (options == null) {
    return {};
  }

  if (!options.containsKey("actions")) {
    return {};
  }

  var actions = options["actions"];

  return actions["POST"] ?? actions["PUT"] ?? actions["PATCH"] ?? {};
}

/*
 * Launch an API-driven form,
 * which uses the OPTIONS metadata (at the provided URL)
 * to determine how the form elements should be rendered!
 */

Future<bool> launchApiForm(String url, Map<String, dynamic> fields, {String method = "PATCH"}) async {

  dynamic options = await InvenTreeAPI().options(url);

  // null response from server
  if (options == null) {
    return false;
  }

  var availableFields = extractFields(options);

  if (availableFields.isEmpty) {
    print("Empty fields {} returned from ${url}");
    return false;
  }

  // Construct a list of APIFormField objects
  List<APIFormField> formFields = [];

  // Iterate through the provided fields we wish to display
  for (String fieldName in fields.keys) {

    // Check that the field is actually available at the API endpoint
    if (!availableFields.containsKey(fieldName)) {
      print("Field '${fieldName}' not available at '${url}'");
      continue;
    }

    var remoteField = availableFields[fieldName] ?? {};
    var localField = fields[fieldName] ?? {};

    // Override defined field parameters, if provided
    for (String key in localField.keys) {
      // Special consideration
      if (key == "filters") {

      } else {
        String? val = localField[key];

        if (val != null) {
          remoteField[key] = val;
        }
      }
    }

    formFields.add(APIFormField(fieldName, remoteField));
  }

  for (var ff in formFields) {
    print("${ff.name} -> ${ff.label} (${ff.helpText})");
  }

  return true;
}