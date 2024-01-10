
import "dart:io";

import "package:intl/intl.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:dropdown_search/dropdown_search.dart";
import "package:datetime_picker_formfield/datetime_picker_formfield.dart";
import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/tones.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/project_code.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";


/*
 * Class that represents a single "form field",
 * defined by the InvenTree API
 */
class APIFormField {

  // Constructor
  APIFormField(this.name, this.data);

  // File to be uploaded for this filed
  File? attachedfile;

  // Name of this field
  final String name;

  // JSON data which defines the field
  final Map<String, dynamic> data;

  // JSON field definition provided by the server
  Map<String, dynamic> definition = {};

  dynamic initial_data;

  // Return the "lookup path" for this field, within the server data
  String get lookupPath {

    // Simple top-level case
    if (parent.isEmpty && !nested) {
      return name;
    }

    List<String> path = [];

    if (parent.isNotEmpty) {
      path.add(parent);
      path.add("child");
    }

    if (nested) {
      path.add("children");
      path.add(name);
    }

    return path.join(".");
  }

  /*
   * Extract a field parameter from the provided field definition.
   *
   * - First the user-provided data is checked
   * - Second, the server-provided definition is checked
   *
   * - Finally, return null
   */
  dynamic getParameter(String key) {
    if (data.containsKey(key)) {
      return data[key];
    } else if (definition.containsKey(key)) {
      return definition[key];
    } else {
      return null;
    }
  }

  // Get the "api_url" associated with a related field
  String get api_url => (getParameter("api_url") ?? "") as String;

  // Get the "model" associated with a related field
  String get model => (getParameter("model") ?? "") as String;

  // Is this field hidden?
  bool get hidden => (getParameter("hidden") ?? false) as bool;

  // Is this field nested? (Nested means part of an array)
  // Note: This parameter is only defined locally
  bool get nested => (data["nested"] ?? false) as bool;

  // What is the "parent" field of this field?
  // Note: This parameter is only defined locally
  String get parent => (data["parent"] ?? "") as String;

  bool get isSimple => !nested && parent.isEmpty;

  // Is this field read only?
  bool get readOnly => (getParameter("read_only") ?? false) as bool;

  bool get multiline => (getParameter("multiline") ?? false) as bool;

  // Get the "value" as a string (look for "default" if not available)
  dynamic get value => data["value"] ?? data["instance_value"] ?? defaultValue;

  // Render value to string (for form submission)
  String renderValueToString() {
    if (data["value"] == null) {
      return "";
    } else {
      return data["value"].toString();
    }
  }

  // Get the "default" as a string
  dynamic get defaultValue => getParameter("default");

  // Construct a set of "filters" for this field (e.g. related field)
  Map<String, String> get filters {

    Map<String, String> _filters = {};

    // Start with the field "definition" (provided by the server)
    if (definition.containsKey("filters")) {

      try {
        var fDef = definition["filters"] as Map<String, dynamic>;

        fDef.forEach((String key, dynamic value) {
          _filters[key] = value.toString();
        });

      } catch (error) {
        // pass
      }
    }

    // Next, look at any "instance_filters" provided by the server
    if (definition.containsKey("instance_filters")) {

      try {
        var fIns = definition["instance_filters"] as Map<String, dynamic>;

        fIns.forEach((String key, dynamic value) {
          _filters[key] = value.toString();
        });
      } catch (error) {
        // pass
      }

    }

    // Finally, augment or override with any filters provided by the calling function
    if (data.containsKey("filters")) {
      try {
        var fDat = data["filters"] as Map<String, dynamic>;

        fDat.forEach((String key, dynamic value) {
          _filters[key] = value.toString();
        });
      } catch (error) {
        // pass
      }
    }

    return _filters;

  }

  bool hasErrors() => errorMessages().isNotEmpty;

  // Extract error messages from the server response
  void extractErrorMessages(APIResponse response) {

    dynamic errors;

    if (isSimple) {
      // Simple fields are easily handled
      errors = response.data[name];
    } else {
      if (parent.isNotEmpty) {
        dynamic parentElement = response.data[parent];

        // Extract from list
        if (parentElement is List) {
          parentElement = parentElement[0];
        }

        if (parentElement is Map) {
          errors = parentElement[name];
        }
      }
    }

    data["errors"] = errors;
  }

  // Return the error message associated with this field
  List<String> errorMessages() {

    dynamic errors = data["errors"] ?? [];

    // Handle the case where a single error message is returned
    if (errors is String) {
      errors = [errors];
    }

    errors = errors as List<dynamic>;

    List<String> messages = [];

    for (dynamic error in errors) {
      messages.add(error.toString());
    }

    return messages;
  }

  // Is this field required?
  bool get required => (getParameter("required") ?? false) as bool;

  String get type => (getParameter("type") ?? "").toString();

  String get label => (getParameter("label") ?? "").toString();

  String get helpText => (getParameter("help_text") ?? "").toString();

  String get placeholderText => (getParameter("placeholder") ?? "").toString();

  List<dynamic> get choices => (getParameter("choices") ?? []) as List<dynamic>;

  Future<void> loadInitialData() async {

    // Only for "related fields"
    if (type != "related field") {
      return;
    }

    // Null value? No point!
    if (value == null) {
      return;
    }

    int? pk = int.tryParse(value.toString());

    if (pk == null) {
      return;
    }

    String url = api_url + "/" + pk.toString() + "/";

    final APIResponse response = await InvenTreeAPI().get(
      url,
      params: filters,
    );

    if (response.successful()) {
      initial_data = response.data;
    }
  }

  // Construct a widget for this input
  Widget constructField(BuildContext context) {

    switch (type) {
      case "string":
      case "url":
        return _constructString();
      case "boolean":
        return _constructBoolean();
      case "related field":
        return _constructRelatedField();
      case "float":
      case "decimal":
        return _constructFloatField();
      case "choice":
        return _constructChoiceField();
      case "file upload":
      case "image upload":
        return _constructFileField();
      case "date":
        return _constructDateField();
      case "barcode":
        return _constructBarcodeField(context);
      default:
        return ListTile(
          title: Text(
            "Unsupported field type: '${type}' for field '${name}'",
            style: TextStyle(
                color: COLOR_DANGER,
                fontStyle: FontStyle.italic),
          )
        );
    }
  }

  // Field for capturing a barcode
  Widget _constructBarcodeField(BuildContext context) {

    TextEditingController controller = TextEditingController();

    String barcode = (value ?? "").toString();

    if (barcode.isEmpty) {
      barcode = L10().barcodeNotAssigned;
    }

    controller.text = barcode;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: required ? label + "*" : label,
        labelStyle: _labelStyle(),
        helperText: helpText,
        helperStyle: _helperStyle(),
        hintText: placeholderText,
      ),
      child: ListTile(
        title: TextField(
          readOnly: true,
          controller: controller,
        ),
        trailing: IconButton(
          icon: Icon(Icons.qr_code),
          onPressed: () async {
            var handler = UniqueBarcodeHandler((String hash) {
              controller.text = hash;
              data["value"] = hash;

              barcodeSuccessTone();

              showSnackIcon(
                  L10().barcodeAssigned,
                  success: true
              );
            });

            scanBarcode(context, handler: handler);
          },
        ),
      )
    );

  }

  // Field for displaying and selecting dates
  Widget _constructDateField() {

    DateTime? currentDate = DateTime.tryParse((value ?? "")as String);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _labelStyle(),
        helperStyle: _helperStyle(),
        helperText: helpText,
      ),
      child: DateTimeField(
        format: DateFormat("yyyy-MM-dd"),
        initialValue: currentDate,
        onChanged: (DateTime? time) {
          // Save the time string
          if (time == null) {
            data["value"] = null;
          } else {
            data["value"] = time.toString().split(" ").first;
          }
        },
        onShowPicker: (context, value) async {
          final time = await showDatePicker(
            context: context,
            initialDate: currentDate ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );

          return time;
        },
      )
    );

  }


  // Field for selecting and uploading files
  Widget _constructFileField() {

    TextEditingController controller = TextEditingController();

    controller.text = (attachedfile?.path ?? L10().attachmentSelect).split("/").last;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      child: ListTile(
        title: TextField(
          readOnly: true,
          controller: controller,
        ),
        trailing: IconButton(
          icon: FaIcon(FontAwesomeIcons.circlePlus),
          onPressed: () async {
            FilePickerDialog.pickFile(
              message: L10().attachmentSelect,
              onPicked: (file) {
                // Display the filename
                controller.text = file.path.split("/").last;

                // Save the file
                attachedfile = file;
              }
            );
          },
        )
      )
    );
  }

  // Field for selecting from multiple choice options
  Widget _constructChoiceField() {

    dynamic initial;

    // Check if the current value is within the allowed values
    for (var opt in choices) {
      if (opt["value"] == value) {
        initial = opt;
        break;
      }
    }

    return DropdownSearch<dynamic>(
      popupProps: PopupProps.bottomSheet(
        showSelectedItems: false,
        searchFieldProps: TextFieldProps(
          autofocus: true
        )
      ),
      selectedItem: initial,
      items: choices,
      dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
        labelText: label,
        hintText: helpText,
      )),
      onChanged: null,
      clearButtonProps: ClearButtonProps(isVisible: !required),
      itemAsString: (dynamic item) {
        return (item["display_name"] ?? "") as String;
      },
      onSaved: (item) {
        if (item == null) {
          data["value"] = null;
        } else {
          data["value"] = item["value"];
        }
      });
  }

  // Construct a floating point numerical input field
  Widget _constructFloatField() {

    double initial = double.tryParse(value.toString()) ?? 0;

    return TextFormField(
      decoration: InputDecoration(
        labelText: required ? label + "*" : label,
        labelStyle: _labelStyle(),
        helperText: helpText,
        helperStyle: _helperStyle(),
        hintText: placeholderText,
      ),
      initialValue: simpleNumberString(initial),
      keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
      validator: (value) {

        double? quantity = double.tryParse(value.toString());

        if (quantity == null) {
          return L10().numberInvalid;
        }

        return null;
      },
      onSaved: (val) {
        data["value"] = val;
      },
    );

  }

  // Construct an input for a related field
  Widget _constructRelatedField() {
    return DropdownSearch<dynamic>(
      popupProps: PopupProps.bottomSheet(
        showSelectedItems: true,
        isFilterOnline: true,
        showSearchBox: true,
        itemBuilder: (context, item, isSelected) {
          return _renderRelatedField(name, item, isSelected, true);
        },
        emptyBuilder: (context, item) {
          return _renderEmptyResult();
        },
        searchFieldProps: TextFieldProps(
          autofocus: true
        )
      ),
      selectedItem: initial_data,
      asyncItems: (String filter) async {
        Map<String, String> _filters = {
          ..._relatedFieldFilters(),
          ...filters,
        };

        _filters["search"] = filter;
        _filters["offset"] = "0";
        _filters["limit"] = "25";

        final APIResponse response = await InvenTreeAPI().get(api_url, params: _filters);

        if (response.isValid()) {
          return response.resultsList();
        } else {
          return [];
        }
      },
      clearButtonProps: ClearButtonProps(
        isVisible: !required
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
        labelText: label,
        hintText: helpText,
      )),
      onChanged: null,
      itemAsString: (dynamic item) {
        Map<String, dynamic> data = item as Map<String, dynamic>;

        switch (model) {
          case "part":
            return InvenTreePart.fromJson(data).fullname;
          case "partcategory":
            return InvenTreePartCategory.fromJson(data).pathstring;
          case "stocklocation":
            return InvenTreeStockLocation.fromJson(data).pathstring;
          default:
            return "itemAsString not implemented for '${model}'";
        }
      },
      dropdownBuilder: (context, item) {
        return _renderRelatedField(name, item, true, false);
      },
      onSaved: (item) {
        if (item != null) {
          data["value"] = item["pk"];
        } else {
          data["value"] = null;
        }
      },
      compareFn: (dynamic item, dynamic selectedItem) {
        // Comparison is based on the PK value

        if (item == null || selectedItem == null) {
          return false;
        }

        bool result = false;

        try {
          result = item["pk"].toString() == selectedItem["pk"].toString();
        } catch (error) {
          // Catch any conversion errors
          result = false;
        }

        return result;
      });
  }

  // Construct a set of custom filters for the dropdown search
  Map<String, String> _relatedFieldFilters() {

    switch (model) {
      case "supplierpart":
        return InvenTreeSupplierPart().defaultListFilters();
      case "stockitem":
        return InvenTreeStockItem().defaultListFilters();
    }

    return {};
  }

  // Render a "related field" based on the "model" type
  Widget _renderRelatedField(String fieldName, dynamic item, bool selected, bool extended) {

    // Convert to JSON
    Map<String, dynamic> data = {};

    try {
      if (item is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(item);
      } else {
        data = {};
      }
    } catch (error, stackTrace) {
      data = {};

      sentryReportError(
        "_renderRelatedField", error, stackTrace,
        context: {
          "method": "_renderRelateField",
          "field_name": fieldName,
          "item": item.toString(),
          "selected": selected.toString(),
          "extended": extended.toString(),
        }
      );
    }

    switch (model) {
      case "part":
        var part = InvenTreePart.fromJson(data);

        return ListTile(
          title: Text(
              part.fullname,
              style: TextStyle(fontWeight: selected && extended ? FontWeight.bold : FontWeight.normal)
          ),
          subtitle: extended ? Text(
            part.description,
            style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
          ) : null,
          leading: extended ? InvenTreeAPI().getThumbnail(part.thumbnail) : null,
        );

      case "supplierpart":
        var part = InvenTreeSupplierPart.fromJson(data);

        return ListTile(
          title: Text(part.SKU),
          subtitle: Text(part.partName),
          leading: extended ? InvenTreeAPI().getThumbnail(part.partImage) : null,
          trailing: extended && part.supplierImage.isNotEmpty ? InvenTreeAPI().getThumbnail(part.supplierImage) : null,
        );
      case "partcategory":

        var cat = InvenTreePartCategory.fromJson(data);

        return ListTile(
          title: Text(
              cat.pathstring,
              style: TextStyle(fontWeight: selected && extended ? FontWeight.bold : FontWeight.normal)
          ),
          subtitle: extended ? Text(
            cat.description,
            style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
          ) : null,
        );
      case "stockitem":
        var item = InvenTreeStockItem.fromJson(data);

        return ListTile(
          title: Text(
            item.partName,
          ),
          leading: InvenTreeAPI().getThumbnail(item.partThumbnail),
          trailing: Text(item.quantityString()),
        );
      case "stocklocation":

        var loc = InvenTreeStockLocation.fromJson(data);

        return ListTile(
          title: Text(
              loc.pathstring,
              style: TextStyle(fontWeight: selected && extended ? FontWeight.bold : FontWeight.normal)
          ),
          subtitle: extended ? Text(
            loc.description,
            style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
          ) : null,
        );
      case "salesordershipment":
        var shipment = InvenTreeSalesOrderShipment.fromJson(data);

        return ListTile(
          title: Text(shipment.reference),
          subtitle: Text(shipment.tracking_number),
          trailing: shipment.shipped ? Text(shipment.shipment_date!) : null,
        );
      case "owner":
        String name = (data["name"] ?? "") as String;
        bool isGroup = (data["label"] ?? "") == "group";
        return ListTile(
          title: Text(name),
          leading: FaIcon(isGroup ? FontAwesomeIcons.users : FontAwesomeIcons.user),
        );
      case "contact":
        String name = (data["name"] ?? "") as String;
        String role = (data["role"] ?? "") as String;
        return ListTile(
          title: Text(name),
          subtitle: Text(role),
        );
      case "company":
        var company = InvenTreeCompany.fromJson(data);
        return ListTile(
            title: Text(company.name),
            subtitle: extended ? Text(company.description) : null,
            leading: InvenTreeAPI().getThumbnail(company.thumbnail)
        );
      case "projectcode":
        var project_code = InvenTreeProjectCode.fromJson(data);
        return ListTile(
            title: Text(project_code.code),
            subtitle: Text(project_code.description),
            leading: FaIcon(FontAwesomeIcons.list)
        );
      default:
        return ListTile(
          title: Text(
              "Unsupported model",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: COLOR_DANGER
              )
          ),
          subtitle: Text("Model '${model}' rendering not supported"),
        );
    }
  }

  // Construct a widget to instruct the user that no results were found
  Widget _renderEmptyResult() {
    return ListTile(
      leading: FaIcon(FontAwesomeIcons.magnifyingGlass),
      title: Text(L10().noResults),
      subtitle: Text(
        L10().queryNoResults,
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  }


  // Construct a string input element
  Widget _constructString() {

    if (readOnly) {
      return ListTile(
        title: Text(label),
        subtitle: Text(helpText),
        trailing: Text(value.toString()),
      );
    }

    return TextFormField(
      decoration: InputDecoration(
        labelText: required ? label + "*" : label,
        labelStyle: _labelStyle(),
        helperText: helpText,
        helperStyle: _helperStyle(),
        hintText: placeholderText,
      ),
      readOnly: readOnly,
      maxLines: multiline ? null : 1,
      expands: false,
      initialValue: (value ?? "") as String,
      onSaved: (val) {
        data["value"] = val;
      },
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          // return L10().valueCannotBeEmpty;
        }

        return null;
      },
    );
  }

  // Construct a boolean input element
  Widget _constructBoolean() {

    bool? initial_value;

    if (value is bool || value == null) {
      initial_value = value as bool?;
    } else {
      String vs = value.toString().toLowerCase();
      initial_value = ["1", "true", "yes"].contains(vs);
    }

    return CheckBoxField(
      label: label,
      labelStyle: _labelStyle(),
      helperText: helpText,
      helperStyle: _helperStyle(),
      initial: initial_value,
      tristate: (getParameter("tristate") ?? false) as bool,
      onSaved: (val) {
        data["value"] = val;
      },
    );
  }

  TextStyle _labelStyle() {
    return TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      fontFamily: "arial",
      color: hasErrors() ? COLOR_DANGER : null,
      fontStyle: FontStyle.normal,
    );
  }

  TextStyle _helperStyle() {
    return TextStyle(
      fontStyle: FontStyle.italic,
      color: hasErrors() ? COLOR_DANGER : null,
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

  var data = response.asMap();

  if (!data.containsKey("actions")) {
    return {};
  }

  var actions = response.data["actions"] as Map<String, dynamic>;

  dynamic result = actions["POST"] ?? actions["PUT"] ?? actions["PATCH"] ?? {};

  return result as Map<String, dynamic>;
}

/*
 * Extract a field definition (map) from the provided JSON data.
 *
 * Notes:
 * - If the field is a top-level item, the provided "path" may be a simple string (e.g. "quantity"),
 * - If the field is buried in the JSON data, the "path" may use a dotted notation e.g. "items.child.children.quantity"
 *
 * The map "tree" is traversed based on the provided lookup string, which can use dotted notation.
 * This allows complex paths to be used to lookup field information.
 */
Map<String, dynamic> extractFieldDefinition(Map<String, dynamic> data, String lookup) {

  List<String> path = lookup.split(".");

  // Shadow copy the data for path traversal
  Map<String, dynamic> _data = data;

  // Iterate through all but the last element of the path
  for (int ii = 0; ii < (path.length - 1); ii++) {

    String el = path[ii];

    if (!_data.containsKey(el)) {
      print("Could not find field definition for ${lookup}:");
      print("- Key ${el} missing at index ${ii}");
      return {};
    }

    try {
      _data = _data[el] as Map<String, dynamic>;
    } catch (error, stackTrace) {
      print("Could not find sub-field element '${el}' for ${lookup}:");
      print(error.toString());

      // Report the error
      sentryReportError(
        "apiForm.extractFieldDefinition : path traversal",
        error, stackTrace,
        context: {
          "path": path.toString(),
          "el": el,
        }
      );
      return {};
    }
  }

  String el = path.last;

  if (!_data.containsKey(el)) {
    return {};
  } else {

    try {
      Map<String, dynamic> definition = _data[el] as Map<String, dynamic>;

      return definition;
    } catch (error, stacktrace) {
      print("Could not find field definition for ${lookup}");
      print(error.toString());

      // Report the error
      sentryReportError(
        "apiForm.extractFieldDefinition : as map",
        error, stacktrace,
        context: {
          "el": el.toString(),
        }
      );

      return {};
    }

  }
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

Future<void> launchApiForm(
    BuildContext context, String title, String url, Map<String, dynamic> fields,
    {
      String fileField = "",
      Map<String, dynamic> modelData = const {},
      String method = "PATCH",
      Function(Map<String, dynamic>)? onSuccess,
      Function? onCancel,
      IconData icon = FontAwesomeIcons.floppyDisk,
    }) async {

  showLoadingOverlay(context);

  // List of fields defined by the server
  Map<String, dynamic> serverFields = {};

  if (url.isNotEmpty) {

    var options = await InvenTreeAPI().options(url);

    // Invalid response from server
    if (!options.isValid()) {
      hideLoadingOverlay();
      return;
    }

    serverFields = extractFields(options);

    if (serverFields.isEmpty) {
      // User does not have permission to perform this action
      showSnackIcon(
        L10().response403,
        icon: FontAwesomeIcons.userXmark,
      );

      hideLoadingOverlay();
      return;
    }
  }

  // Construct a list of APIFormField objects
  List<APIFormField> formFields = [];

  APIFormField field;

  for (String fieldName in fields.keys) {

    dynamic data = fields[fieldName];

    Map<String, dynamic> fieldData = {};

    if (data is Map) {
      fieldData = Map<String, dynamic>.from(data);
    }

    // Iterate through the provided fields we wish to display

    field = APIFormField(fieldName, fieldData);

    // Extract the definition of this field from the data received from the server
    field.definition = extractFieldDefinition(serverFields, field.lookupPath);

    // Skip fields with empty definitions
    if (url.isNotEmpty && field.definition.isEmpty) {
      print("Warning: Empty field definition for field '${fieldName}'");
    }

    // Add instance value to the field
    dynamic model_value = modelData[fieldName];

    if (model_value != null) {
      field.data["instance_value"] = model_value;

      if (field.data["value"] == null) {
        field.data["value"] = model_value;
      }
    }
    formFields.add(field);
  }

  // Grab existing data for each form field
  for (var field in formFields) {
    await field.loadInitialData();
  }

  hideLoadingOverlay();

  // Now, launch a new widget!
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => APIFormWidget(
      title,
      url,
      formFields,
      method,
      onSuccess: onSuccess,
      fileField: fileField,
      icon: icon,
    ))
  );
}


class APIFormWidget extends StatefulWidget {

  const APIFormWidget(
      this.title,
      this.url,
      this.fields,
      this.method,
      {
        Key? key,
        this.onSuccess,
        this.fileField = "",
        this.icon = FontAwesomeIcons.floppyDisk,
      }
      ) : super(key: key);

  //! Form title to display
  final String title;

  //! API URL
  final String url;

  //! API method
  final String method;

  final String fileField;

  // Icon
  final IconData icon;

  final List<APIFormField> fields;

  final Function(Map<String, dynamic>)? onSuccess;

  @override
  _APIFormWidgetState createState() => _APIFormWidgetState();

}


class _APIFormWidgetState extends State<APIFormWidget> {

  _APIFormWidgetState() : super();

  final _formKey = GlobalKey<FormState>();

  List<String> nonFieldErrors = [];

  bool spacerRequired = false;

  List<Widget> _buildForm() {

    List<Widget> widgets = [];

    // Display non-field errors first
    if (nonFieldErrors.isNotEmpty) {
      for (String error in nonFieldErrors) {
        widgets.add(
          ListTile(
            title: Text(
              error,
              style: TextStyle(
                color: COLOR_DANGER,
              ),
            ),
            leading: FaIcon(
              FontAwesomeIcons.circleExclamation,
              color: COLOR_DANGER
            ),
          )
        );
      }

      widgets.add(Divider(height: 5));

    }

    for (var field in widget.fields) {

      if (field.hidden) {
        continue;
      }

      // Add divider before some widgets
      if (spacerRequired) {
        switch (field.type) {
          case "related field":
          case "choice":
            widgets.add(Divider(height: 15));
            break;
          default:
            break;
        }
      }

      widgets.add(field.constructField(context));

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

      // Add divider after some widgets
      switch (field.type) {
        case "related field":
        case "choice":
          widgets.add(Divider(height: 15));
          spacerRequired = false;
          break;
        default:
          spacerRequired = true;
          break;
      }
    }

    return widgets;
  }

  Future<APIResponse> _submit(Map<String, dynamic> data) async {

    // If a file upload is required, we have to handle the submission differently
    if (widget.fileField.isNotEmpty) {

      // Pop the "file" field
      data.remove(widget.fileField);

      for (var field in widget.fields) {
        if (field.name == widget.fileField) {

          File? file = field.attachedfile;

          if (file != null) {

            // A valid file has been supplied
            final response = await InvenTreeAPI().uploadFile(
              widget.url,
              file,
              name: widget.fileField,
              fields: data,
            );

            return response;
          }
        }
      }
    }

    if (widget.method == "POST") {

      showLoadingOverlay(context);
      final response =  await InvenTreeAPI().post(
        widget.url,
        body: data,
        expectedStatusCode: null
      );
      hideLoadingOverlay();

      return response;

    } else {
      showLoadingOverlay(context);
      final response = await InvenTreeAPI().patch(
        widget.url,
        body: data,
        expectedStatusCode: null
      );
      hideLoadingOverlay();

      return response;
    }
  }

  void extractNonFieldErrors(APIResponse response) {

    List<String> errors = [];

    Map<String, dynamic> data = response.asMap();

    // Potential keys representing non-field errors
    List<String> keys = [
      "__all__",
      "non_field_errors",
      "errors",
    ];

    for (String key in keys) {
      if (data.containsKey(key)) {
        dynamic result = data[key];

        if (result is String) {
          errors.add(result);
        } else if (result is List) {
          for (dynamic element in result) {
            errors.add(element.toString());
          }
        }
      }
    }

    nonFieldErrors = errors;
  }

  /* Check for errors relating to an *unhandled* field name
  * These errors will not be displayed and potentially confuse the user
  * So, we need to know if these are ever happening
  */
  void checkInvalidErrors(APIResponse response) {
    var errors = response.asMap();

    for (String fieldName in errors.keys) {

      bool match = false;

      switch (fieldName) {
        case "__all__":
        case "non_field_errors":
        case "errors":
          // ignore these global fields
          match = true;
          continue;
        default:
          for (var field in widget.fields) {

            // Hidden fields can't display errors, so we won't match
            if (field.hidden) {
              continue;
            }

            if (field.name == fieldName) {
              // Direct Match found!
              match = true;
              break;
            } else if (field.parent == fieldName) {

              var error = errors[fieldName];

              if (error is List) {
                for (var el in error) {
                  if (el is Map && el.containsKey(field.name)) {
                    match = true;
                    break;
                  }
                }
              } else if (error is Map && error.containsKey(field.name)) {
                match = true;
                break;
              }
            }
          }

          break;
      }

      if (!match) {
        // Match for an unknown / unsupported field
        sentryReportMessage(
          "API form returned error for unsupported field",
          context: {
            "url": response.url,
            "status_code": response.statusCode.toString(),
            "field": fieldName,
            "error_message": response.data.toString(),
          }
        );
      }
    }
  }

  /*
   * Submit the form data to the server, and handle the results
   */
  Future<void> _save(BuildContext context) async {

    // Package up the form data
    Map<String, dynamic> data = {};

    // Iterate through and find "simple" top-level fields

    for (var field in widget.fields) {

      if (field.readOnly) {
        continue;
      }

      if (field.isSimple) {
        // Simple top-level field data
        data[field.name] = field.data["value"];
      } else {
        // Not so simple... (WHY DID I MAKE THE API SO COMPLEX?)
        if (field.parent.isNotEmpty) {

          // TODO: This is a dirty hack, there *must* be a cleaner way?!

          dynamic parent = data[field.parent] ?? {};

          // In the case of a "nested" object, we need to extract the first item
          if (parent is List) {
            parent = parent.first;
          }

          parent[field.name] = field.data["value"];

          // Nested fields must be handled as an array!
          // For now, we only allow single length nested fields
          if (field.nested) {
            parent = [parent];
          }

          data[field.parent] = parent;
        }
      }
    }

    // Run custom onSuccess function
    var successFunc = widget.onSuccess;

    // An "empty" URL means we don't want to submit the form anywhere
    // Perhaps we just want to process the data?
    if (widget.url.isEmpty) {
      // Hide the form
      Navigator.pop(context);

      if (successFunc != null) {
        // Return the raw "submitted" data, rather than the server response
        successFunc(data);
      }

      return;
    }

    final response = await _submit(data);

    if (!response.isValid()) {
      showServerError(widget.url, L10().serverError, L10().responseInvalid);
      return;
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        // Form was successfully validated by the server

        // Hide this form
        Navigator.pop(context);

        if (successFunc != null) {

          // Ensure the response is a valid JSON structure
          Map<String, dynamic> json = {};

          var data = response.asMap();

          for (String key in data.keys) {
            json[key.toString()] = data[key];
          }

          successFunc(json);
        }
        return;
      case 400:
        // Form submission / validation error
        showSnackIcon(
          L10().formError,
          success: false
        );

        // Update field errors
        for (var field in widget.fields) {
          field.extractErrorMessages(response);
        }

        extractNonFieldErrors(response);
        checkInvalidErrors(response);
        break;
      case 401:
        showSnackIcon(
          "401: " + L10().response401,
          success: false
        );
        break;
      case 403:
        showSnackIcon(
          "403: " + L10().response403,
          success: false,
        );
        break;
      case 404:
        showSnackIcon(
          "404: " + L10().response404,
          success: false,
        );
        break;
      case 405:
        showSnackIcon(
          "405: " + L10().response405,
          success: false,
        );
        break;
      case 500:
        showSnackIcon(
          "500: " + L10().response500,
          success: false,
        );
        break;
      default:
        showSnackIcon(
          "${response.statusCode}: " + L10().responseInvalid,
          success: false,
        );
        break;
    }

    setState(() {
      // Refresh the form
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: FaIcon(widget.icon),
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
