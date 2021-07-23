import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/api.dart';
import 'package:inventree/app_colors.dart';
import 'package:inventree/widget/dialogs.dart';
import 'package:inventree/widget/fields.dart';
import 'package:inventree/l10.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inventree/widget/snacks.dart';
import 'package:one_context/one_context.dart';


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

  bool hasErrors() => errorMessages().length > 0;

  // Return the error message associated with this field
  List<String> errorMessages() {
    List<dynamic> errors = data['errors'] ?? [];

    List<String> messages = [];

    for (dynamic error in errors) {
      messages.add(error.toString());
    }

    return messages;
  }

  // Is this field required?
  bool get required => (data['required'] ?? false) as bool;

  String get type => (data['type'] ?? '').toString();

  String get label => (data['label'] ?? '').toString();

  String get helpText => (data['help_text'] ?? '').toString();

  String get placeholderText => (data['placeholder'] ?? '').toString();

  // Construct a widget for this input
  Widget constructField() {
    switch (type) {
      case "string":
      case "url":
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
        labelStyle: _labelStyle(),
        helperText: helpText,
        helperStyle: _helperStyle(),
        hintText: placeholderText,
      ),
      initialValue: value ?? '',
      onSaved: (val) {
        data["value"] = val;
      },
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          // return L10().valueCannotBeEmpty;
        }
      },
    );
  }

  // Construct a boolean input element
  Widget _constructBoolean() {

    return CheckBoxField(
      label: label,
      labelStyle: _labelStyle(),
      helperText: helpText,
      helperStyle: _helperStyle(),
      initial: value,
      onSaved: (val) {
        data['value'] = val;
      },
    );
  }

  TextStyle _labelStyle() {
    return new TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: hasErrors() ? COLOR_DANGER : COLOR_GRAY,
    );
  }

  TextStyle _helperStyle() {
    return new TextStyle(
      fontStyle: FontStyle.italic,
      color: hasErrors() ? COLOR_DANGER : COLOR_GRAY,
    );
  }

}


/*
 * Extract field options from a returned OPTIONS request
 */
Map<String, dynamic> extractFields(APIResponse response) {

  if (!response.isValid()) {
    return {};
  }

  if (!response.data.containsKey("actions")) {
    return {};
  }

  var actions = response.data["actions"];

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

Future<void> launchApiForm(BuildContext context, String title, String url, Map<String, dynamic> fields, {Map<String, dynamic> modelData = const {}, String method = "PATCH", Function? onSuccess, Function? onCancel}) async {

  var options = await InvenTreeAPI().options(url);

  final _formKey = new GlobalKey<FormState>();

  // Invalid response from server
  if (!options.isValid()) {
    return;
  }

  var availableFields = extractFields(options);

  if (availableFields.isEmpty) {
    // User does not have permission to perform this action
    showSnackIcon(
      L10().response403,
      icon: FontAwesomeIcons.userTimes,
    );

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

  // Now, launch a new widget!
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => APIFormWidget(
        title,
        url,
        formFields,
        onSuccess: onSuccess,
    ))
  );
}


class APIFormWidget extends StatefulWidget {

  //! Form title to display
  final String title;

  //! API URL
  final String url;

  final List<APIFormField> fields;

  Function? onSuccess;

  APIFormWidget(
      this.title,
      this.url,
      this.fields,
      {
        Key? key,
        this.onSuccess,
      }
  ) : super(key: key);

  @override
  _APIFormWidgetState createState() => _APIFormWidgetState(title, url, fields, onSuccess);

}


class _APIFormWidgetState extends State<APIFormWidget> {

  final _formKey = new GlobalKey<FormState>();

  String title;

  String url;

  List<APIFormField> fields;

  Function? onSuccess;

  _APIFormWidgetState(this.title, this.url, this.fields, this.onSuccess) : super();

  List<Widget> _buildForm() {

    List<Widget> widgets = [];

    for (var field in fields) {

      if (field.hidden) {
        continue;
      }

      widgets.add(field.constructField());

      if (field.hasErrors()) {
        for (String error in field.errorMessages()) {
          widgets.add(
            ListTile(
              title: Text(
                error,
                style: TextStyle(
                  color: COLOR_DANGER,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
              )
            )
          );
        }
      }
    }

    // TODO: Add a "Save" button
    // widgets.add(Spacer());

    /*
    widgets.add(
      TextButton(
        child: Text(
          L10().save
        ),
        onPressed: null,
      )
    );
    */

    return widgets;
  }

  Future<void> _save(BuildContext context) async {

    // Package up the form data
    Map<String, String> _data = {};

    for (var field in fields) {
      _data[field.name] = field.value.toString();
    }

    // TODO: Handle "POST" forms too!!
    final response = await InvenTreeAPI().patch(
      url,
      body: _data,
    );

    if (!response.isValid()) {
      // TODO: Display an error message!
      return;
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        // Form was successfully validated by the server

        // Hide this form
        Navigator.pop(context);

        // TODO: Display a snackBar

        // Run custom onSuccess function
        var successFunc = onSuccess;

        if (successFunc != null) {
          successFunc();
        }
        return;
      case 400:
        // Form submission / validation error

        // Update field errors
        for (var field in fields) {
          field.data['errors'] = response.data[field.name];
        }
        break;
      // TODO: Other status codes?
    }

    setState(() {
      // Refresh the form
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: FaIcon(FontAwesomeIcons.save),
            onPressed: () {

              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();

                _save(context);
              }
            },
          )
        ]
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildForm(),
          ),
          padding: EdgeInsets.all(16),
        )
      )
    );

  }
}