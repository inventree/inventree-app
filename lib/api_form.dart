import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:one_context/one_context.dart';
import 'package:InvenTree/l10.dart';


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

Future<void> launchApiForm(String title, String url, Map<String, dynamic> fields, {Map<String, dynamic> modelData = const {}, String method = "PATCH"}) async {

  dynamic options = await InvenTreeAPI().options(url);

  // null response from server
  if (options == null) {
    return;
  }

  var availableFields = extractFields(options);

  if (availableFields.isEmpty) {
    print("Empty fields {} returned from ${url}");
    return;
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
      // Special consideration must be taken here!
      if (key == "filters") {
        // TODO: Custom filter updating
      } else {
        remoteField[key] = localField[key];
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
    if (!ff.hidden) {
      widgets.add(ff.constructField());
    }
  }

  final _formKey = new GlobalKey<FormState>();

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        actions: <Widget>[
          // Cancel button
          TextButton(
            child: Text(L10().cancel),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          // Save button
          TextButton(
            child: Text(L10().save),
            onPressed: () {
              // Validate the form
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();

                // Package up the form data
                Map<String, String> formData = {};

                for (var field in formFields) {
                  formData[field.name] = field.value.toString();
                }

                print(formData.toString());

                // Send the data to the server

                // Respond to error message

                // Dismiss the form

              }
            },
          )
        ],
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widgets
            )
          )
        )
      );
    }
  );
}