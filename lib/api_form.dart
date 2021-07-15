import 'dart:convert';

import 'package:InvenTree/api.dart';

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

    print("${fieldName} -> ${remoteField.toString()}");

  }

  return true;
}