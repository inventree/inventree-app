import 'dart:convert';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  // Get the "value" as a string (look for "default" if not available)
  dynamic get value => (data['value'] ?? data['default']);

  // Get the "default" as a string
  dynamic get defaultValue => data['default'];

  // Return the error message associated with this field
  String get errorMessage => data['error'];

  // Is this field required?
  bool get required => (data['required'] ?? false) as bool;

  String get type => (data['type'] ?? '').toString();

  String get label => (data['label'] ?? '').toString();

  String get helpText => (data['help_text'] ?? '').toString();

  // Construct a widget for this input
  Widget constructField() {
    switch (type) {
      case "string":
        return _constructString();
      case "boolean":
        return _constructBoolean();
      default:
        return ListTile(
          title: Text("Unsupported field type: '${type}'")
        );
    }
  }

  // Consturct a string input element
  Widget _constructString() {

    return TextFormField(
      decoration: InputDecoration(
        labelText: required ? label + "*" : label,
        hintText: helpText,
      ),
      initialValue: value ?? '',
      onSaved: (val) {
        data["value"] = val;
        print("${name} -> ${val}");
      },
      validator: (value) {

        // TODO - Custom field validation
      },
    );
  }

  // Construct a boolean input element
  Widget _constructBoolean() {

    return CheckBoxField(
      label: label,
      hint: helpText,
      initial: value,
      onSaved: (val) {
        data['value'] = val;
        print("${name} -> ${val}");
      },
    );
  }
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
 *
 * @param title is the title text to display on the form
 * @param url is the API URl to make the OPTIONS request to
 * @param fields is a map of fields to display (with optional overrides)
 * @param modelData is the (optional) existing modelData
 * @param method is the HTTP method to use to send the form data to the server (e.g. POST / PATCH)
 */

Future<bool> launchApiForm(String title, String url, Map<String, dynamic> fields, {Map<String, dynamic> modelData = const {}, String method = "PATCH"}) async {

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

    // Update fields with existing model data
    for (String key in modelData.keys) {

      dynamic value = modelData[key];

      if (availableFields.containsKey(key)) {
        availableFields[key]['value'] = value;
      }
    }

    formFields.add(APIFormField(fieldName, remoteField));
  }

  List<Widget> widgets = [];

  for (var ff in formFields) {
    widgets.add(ff.constructField());
  }

  final formKey = new GlobalKey<FormState>();

  showFormDialog(title, fields: widgets, key: formKey, callback: () {
    print("submitted, I guess?");
  });

  return true;
}