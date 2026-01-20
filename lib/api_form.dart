import "dart:io";

import "package:intl/intl.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:dropdown_search/dropdown_search.dart";
import "package:datetime_picker_formfield/datetime_picker_formfield.dart";
import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/project_code.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/inventree/sentry.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";

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
 * Class that represents a single "form field",
 * defined by the InvenTree API
 */
class APIFormField {
  // Constructor
  APIFormField(this.name, this.data, {this.formHandler});

  // File to be uploaded for this filed
  File? attachedfile;

  APIFormWidgetState? formHandler;

  // Name of this field
  final String name;

  // JSON data which defines the field
  final Map<String, dynamic> data;

  // Function to update the value of this field
  void setFieldValue(dynamic val) {
    data["value"] = val;
    formHandler?.onValueChanged(name, value);
  }

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

  String get pk_field => (getParameter("pk_field") ?? "pk") as String;

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

    String url = api_url + "/" + value.toString() + "/";

    final APIResponse response = await InvenTreeAPI().get(url, params: filters);

    if (response.successful()) {
      initial_data = response.data;
      formHandler?.onValueChanged(name, value);
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
      case "integer":
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
            style: TextStyle(color: COLOR_DANGER, fontStyle: FontStyle.italic),
          ),
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
        title: TextField(readOnly: true, controller: controller),
        trailing: IconButton(
          icon: Icon(TablerIcons.qrcode),
          onPressed: () async {
            var handler = UniqueBarcodeHandler((String hash) {
              controller.text = hash;
              setFieldValue(hash);
              barcodeSuccess(L10().barcodeAssigned);
            });

            scanBarcode(context, handler: handler);
          },
        ),
      ),
    );
  }

  // Field for displaying and selecting dates
  Widget _constructDateField() {
    DateTime? currentDate = DateTime.tryParse((value ?? "") as String);

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
            setFieldValue(null);
          } else {
            setFieldValue(time.toString().split(" ").first);
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
      ),
    );
  }

  // Field for selecting and uploading files
  Widget _constructFileField() {
    TextEditingController controller = TextEditingController();

    controller.text = (attachedfile?.path ?? L10().attachmentSelect)
        .split("/")
        .last;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      child: ListTile(
        title: TextField(readOnly: true, controller: controller),
        trailing: IconButton(
          icon: Icon(TablerIcons.circle_plus),
          onPressed: () async {
            FilePickerDialog.pickFile(
              message: L10().attachmentSelect,
              onPicked: (file) {
                // Display the filename
                controller.text = file.path.split("/").last;

                // Save the file
                attachedfile = file;
              },
            );
          },
        ),
      ),
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
        searchFieldProps: TextFieldProps(autofocus: true),
      ),
      selectedItem: initial,
      items: choices,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          hintText: helpText,
        ),
      ),
      onChanged: null,
      clearButtonProps: ClearButtonProps(isVisible: !required),
      itemAsString: (dynamic item) {
        return (item["display_name"] ?? "") as String;
      },
      onSaved: (item) {
        if (item == null) {
          setFieldValue(null);
        } else {
          setFieldValue(item["value"]);
        }
      },
    );
  }

  // Construct a floating point numerical input field
  Widget _constructFloatField() {
    // Initial value: try to cast to a valid number
    String initial = "";

    double? initialNumber = double.tryParse(value.toString());

    if (initialNumber != null) {
      initial = simpleNumberString(initialNumber);
    }

    return TextFormField(
      decoration: InputDecoration(
        labelText: required ? label + "*" : label,
        labelStyle: _labelStyle(),
        helperText: helpText,
        helperStyle: _helperStyle(),
        hintText: placeholderText,
      ),
      initialValue: initial,
      keyboardType: TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      validator: (value) {
        value = value?.trim() ?? "";

        // Allow empty numbers, *if* this field is not required
        if (value.isEmpty && !required) {
          return null;
        }

        double? quantity = double.tryParse(value.toString());

        if (quantity == null) {
          return L10().numberInvalid;
        }

        return null;
      },
      onSaved: (val) {
        setFieldValue(val);
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
        searchFieldProps: TextFieldProps(autofocus: true),
      ),
      selectedItem: initial_data,
      asyncItems: (String filter) async {
        Map<String, String> _filters = {..._relatedFieldFilters(), ...filters};

        _filters["search"] = filter;
        _filters["offset"] = "0";
        _filters["limit"] = "25";

        final APIResponse response = await InvenTreeAPI().get(
          api_url,
          params: _filters,
        );

        if (response.isValid()) {
          return response.resultsList();
        } else {
          return [];
        }
      },
      clearButtonProps: ClearButtonProps(isVisible: !required),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          hintText: helpText,
        ),
      ),
      onChanged: (item) {
        if (item != null) {
          setFieldValue(item[pk_field]);
        } else {
          setFieldValue(null);
        }
      },
      onSaved: (item) {
        if (item != null) {
          setFieldValue(item[pk_field]);
        } else {
          setFieldValue(null);
        }
      },
      itemAsString: (dynamic item) {
        Map<String, dynamic> data = item as Map<String, dynamic>;

        switch (model) {
          case InvenTreePart.MODEL_TYPE:
            return InvenTreePart.fromJson(data).fullname;
          case InvenTreeCompany.MODEL_TYPE:
            return InvenTreeCompany.fromJson(data).name;
          case InvenTreePurchaseOrder.MODEL_TYPE:
            return InvenTreePurchaseOrder.fromJson(data).reference;
          case InvenTreeSalesOrder.MODEL_TYPE:
            return InvenTreeSalesOrder.fromJson(data).reference;
          case InvenTreePartCategory.MODEL_TYPE:
            return InvenTreePartCategory.fromJson(data).pathstring;
          case InvenTreeStockLocation.MODEL_TYPE:
            return InvenTreeStockLocation.fromJson(data).pathstring;
          default:
            return "itemAsString not implemented for '${model}'";
        }
      },
      dropdownBuilder: (context, item) {
        return _renderRelatedField(name, item, true, false);
      },
      compareFn: (dynamic item, dynamic selectedItem) {
        // Comparison is based on the PK value

        if (item == null || selectedItem == null) {
          return false;
        }

        bool result = false;

        try {
          result =
              item[pk_field].toString() == selectedItem[pk_field].toString();
        } catch (error) {
          // Catch any conversion errors
          result = false;
        }

        return result;
      },
    );
  }

  // Construct a set of custom filters for the dropdown search
  Map<String, String> _relatedFieldFilters() {
    switch (model) {
      case InvenTreeSupplierPart.MODEL_TYPE:
        return InvenTreeSupplierPart().defaultListFilters();
      case InvenTreeStockItem.MODEL_TYPE:
        return InvenTreeStockItem().defaultListFilters();
      case InvenTreeSalesOrder.MODEL_TYPE:
        return InvenTreeSalesOrder().defaultListFilters();
      default:
        break;
    }

    return {};
  }

  // Render a "related field" based on the "model" type
  Widget _renderRelatedField(
    String fieldName,
    dynamic item,
    bool selected,
    bool extended,
  ) {
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
        "_renderRelatedField",
        error,
        stackTrace,
        context: {
          "method": "_renderRelateField",
          "field_name": fieldName,
          "item": item.toString(),
          "selected": selected.toString(),
          "extended": extended.toString(),
        },
      );
    }

    switch (model) {
      case InvenTreePart.MODEL_TYPE:
        var part = InvenTreePart.fromJson(data);

        return ListTile(
          title: Text(
            part.fullname,
            style: TextStyle(
              fontWeight: selected && extended
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          subtitle: extended
              ? Text(
                  part.description,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                )
              : null,
          leading: extended
              ? InvenTreeAPI().getThumbnail(part.thumbnail)
              : null,
        );
      case InvenTreePartTestTemplate.MODEL_TYPE:
        var template = InvenTreePartTestTemplate.fromJson(data);

        return ListTile(
          title: Text(template.testName),
          subtitle: Text(template.description),
        );
      case InvenTreeSupplierPart.MODEL_TYPE:
        var part = InvenTreeSupplierPart.fromJson(data);

        return ListTile(
          title: Text(part.SKU),
          subtitle: Text(part.partName),
          leading: extended
              ? InvenTreeAPI().getThumbnail(part.partImage)
              : null,
          trailing: extended && part.supplierImage.isNotEmpty
              ? InvenTreeAPI().getThumbnail(part.supplierImage)
              : null,
        );
      case InvenTreePartCategory.MODEL_TYPE:
        var cat = InvenTreePartCategory.fromJson(data);

        return ListTile(
          title: Text(
            cat.pathstring,
            style: TextStyle(
              fontWeight: selected && extended
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          subtitle: extended
              ? Text(
                  cat.description,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                )
              : null,
        );
      case InvenTreeStockItem.MODEL_TYPE:
        var item = InvenTreeStockItem.fromJson(data);

        return ListTile(
          title: Text(item.partName),
          subtitle: Text(item.locationPathString),
          leading: InvenTreeAPI().getThumbnail(item.partThumbnail),
          trailing: Text(item.quantityString()),
        );
      case InvenTreeStockLocation.MODEL_TYPE:
        var loc = InvenTreeStockLocation.fromJson(data);

        return ListTile(
          title: Text(
            loc.pathstring,
            style: TextStyle(
              fontWeight: selected && extended
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          subtitle: extended
              ? Text(
                  loc.description,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                )
              : null,
        );
      case InvenTreeSalesOrderShipment.MODEL_TYPE:
        var shipment = InvenTreeSalesOrderShipment.fromJson(data);

        return ListTile(
          title: Text(shipment.reference),
          subtitle: Text(shipment.tracking_number),
          trailing: shipment.isShipped ? Text(shipment.shipment_date!) : null,
        );
      case "owner":
        String name = (data["name"] ?? "") as String;
        bool isGroup = (data["label"] ?? "") == "group";
        return ListTile(
          title: Text(name),
          leading: Icon(isGroup ? TablerIcons.users : TablerIcons.user),
        );
      case "contact":
        String name = (data["name"] ?? "") as String;
        String role = (data["role"] ?? "") as String;
        return ListTile(title: Text(name), subtitle: Text(role));
      case InvenTreeCompany.MODEL_TYPE:
        var company = InvenTreeCompany.fromJson(data);
        return ListTile(
          title: Text(company.name),
          subtitle: extended ? Text(company.description) : null,
          leading: InvenTreeAPI().getThumbnail(company.thumbnail),
        );
      case InvenTreeProjectCode.MODEL_TYPE:
        var project_code = InvenTreeProjectCode.fromJson(data);
        return ListTile(
          title: Text(project_code.code),
          subtitle: Text(project_code.description),
          leading: Icon(TablerIcons.list),
        );
      case InvenTreeSalesOrder.MODEL_TYPE:
        var so = InvenTreeSalesOrder.fromJson(data);
        return ListTile(
          title: Text(so.reference),
          subtitle: Text(so.description),
          leading: InvenTreeAPI().getThumbnail(
            so.customer?.thumbnail ?? so.customer?.image ?? "",
          ),
        );
      case "labeltemplate":
        return ListTile(
          title: Text((data["name"] ?? "").toString()),
          subtitle: Text((data["description"] ?? "").toString()),
        );
      case "pluginconfig":
        return ListTile(
          title: Text(
            (data["meta"]?["human_name"] ?? data["name"] ?? "").toString(),
          ),
          subtitle: Text((data["meta"]?["description"] ?? "").toString()),
        );
      default:
        return ListTile(
          title: Text(
            "Unsupported model",
            style: TextStyle(fontWeight: FontWeight.bold, color: COLOR_DANGER),
          ),
          subtitle: Text("Model '${model}' rendering not supported"),
        );
    }
  }

  // Construct a widget to instruct the user that no results were found
  Widget _renderEmptyResult() {
    return ListTile(
      leading: Icon(TablerIcons.search),
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
      onChanged: (val) {
        setFieldValue(val);
      },
      onSaved: (val) {
        setFieldValue(val);
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
        setFieldValue(val);
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
 * Extract a field definition (map) from the provided JSON data.
 *
 * Notes:
 * - If the field is a top-level item, the provided "path" may be a simple string (e.g. "quantity"),
 * - If the field is buried in the JSON data, the "path" may use a dotted notation e.g. "items.child.children.quantity"
 *
 * The map "tree" is traversed based on the provided lookup string, which can use dotted notation.
 * This allows complex paths to be used to lookup field information.
 */
Map<String, dynamic> extractFieldDefinition(
  Map<String, dynamic> data,
  String lookup,
) {
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
        error,
        stackTrace,
        context: {"path": path.toString(), "el": el},
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
        error,
        stacktrace,
        context: {"el": el.toString()},
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
  BuildContext context,
  String title,
  String url,
  Map<String, dynamic> fields, {
  String fileField = "",
  Map<String, dynamic> modelData = const {},
  String method = "PATCH",
  Function(Map<String, dynamic>)? onSuccess,
  bool Function(Map<String, dynamic>)? validate,
  Function? onCancel,
  APIFormWidgetState? formHandler,
  IconData icon = TablerIcons.device_floppy,
}) async {
  // List of fields defined by the server
  Map<String, dynamic> serverFields = {};

  if (url.isNotEmpty) {
    showLoadingOverlay();
    var options = await InvenTreeAPI().options(url);
    hideLoadingOverlay();

    // Invalid response from server
    if (!options.isValid()) {
      return;
    }

    serverFields = extractFields(options);

    if (serverFields.isEmpty) {
      // User does not have permission to perform this action
      showSnackIcon(L10().response403, icon: TablerIcons.user_x);
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
        field.setFieldValue(model_value);
      }
    }
    formFields.add(field);
  }

  showLoadingOverlay();

  // Grab existing data for each form field
  for (var field in formFields) {
    await field.loadInitialData();
  }

  hideLoadingOverlay();

  // Now, launch a new widget!
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => APIFormWidget(
        title,
        url,
        formFields,
        method,
        onSuccess: onSuccess,
        validate: validate,
        fileField: fileField,
        state: formHandler,
        icon: icon,
      ),
    ),
  );
}

class APIFormWidget extends StatefulWidget {
  const APIFormWidget(
    this.title,
    this.url,
    this.fields,
    this.method, {
    Key? key,
    this.state,
    this.onSuccess,
    this.validate,
    this.fileField = "",
    this.icon = TablerIcons.device_floppy,
  }) : super(key: key);

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

  final bool Function(Map<String, dynamic>)? validate;

  final APIFormWidgetState? state;

  // Default form handler is constructed if none is provided
  @override
  APIFormWidgetState createState() => state ?? APIFormWidgetState();
}

class APIFormWidgetState extends State<APIFormWidget> {
  APIFormWidgetState() : super();

  final _formKey = GlobalKey<FormState>();

  List<String> nonFieldErrors = [];

  bool spacerRequired = false;

  // Return a list of all fields used for this form
  // The default implementation just returns the fields provided to the widget
  // However, custom form implementations may override this function
  List<APIFormField> get formFields {
    final List<APIFormField> fields = widget.fields;

    // Ensure each field has access to this form handler
    for (var field in fields) {
      field.formHandler ??= this;
    }

    return fields;
  }

  // Callback for when a field value is changed
  // Default implementation does nothing,
  // but custom form implementations may override this function
  void onValueChanged(String field, dynamic value) {}

  Future<void> handleSuccess(
    Map<String, dynamic> submittedData,
    Map<String, dynamic> responseData,
  ) async {
    Navigator.pop(context);
    widget.onSuccess?.call(responseData);
  }

  List<Widget> _buildForm() {
    List<Widget> widgets = [];

    // Display non-field errors first
    if (nonFieldErrors.isNotEmpty) {
      for (String error in nonFieldErrors) {
        widgets.add(
          ListTile(
            title: Text(error, style: TextStyle(color: COLOR_DANGER)),
            leading: Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER),
          ),
        );
      }

      widgets.add(Divider(height: 5));
    }

    for (var field in formFields) {
      if (field.hidden) {
        continue;
      }

      // Add divider before some widgets
      if (spacerRequired) {
        switch (field.type) {
          case "related field":
          case "choice":
            widgets.add(Divider(height: 15));
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
              ),
            ),
          );
        }
      }

      // Add divider after some widgets
      switch (field.type) {
        case "related field":
        case "choice":
          widgets.add(Divider(height: 15));
          spacerRequired = false;
        default:
          spacerRequired = true;
      }
    }

    return widgets;
  }

  Future<APIResponse> _submit(Map<String, dynamic> data) async {
    // If a file upload is required, we have to handle the submission differently
    if (widget.fileField.isNotEmpty) {
      // Pop the "file" field
      data.remove(widget.fileField);

      for (var field in formFields) {
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
      showLoadingOverlay();
      final response = await InvenTreeAPI().post(
        widget.url,
        body: data,
        expectedStatusCode: null,
      );
      hideLoadingOverlay();

      return response;
    } else {
      showLoadingOverlay();
      final response = await InvenTreeAPI().patch(
        widget.url,
        body: data,
        expectedStatusCode: null,
      );
      hideLoadingOverlay();

      return response;
    }
  }

  void extractNonFieldErrors(APIResponse response) {
    List<String> errors = [];

    Map<String, dynamic> data = response.asMap();

    // Potential keys representing non-field errors
    List<String> keys = ["__all__", "non_field_errors", "errors"];

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
          for (var field in formFields) {
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
          },
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

    for (var field in formFields) {
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

    final bool isValid = widget.validate?.call(data) ?? true;

    if (!isValid) {
      return;
    }

    // An "empty" URL means we don't want to submit the form anywhere
    // Perhaps we just want to process the data?
    if (widget.url.isEmpty) {
      // Hide the form
      handleSuccess(data, data);
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
        // Ensure the response is a valid JSON structure
        Map<String, dynamic> json = {};

        var responseData = response.asMap();

        for (String key in responseData.keys) {
          json[key.toString()] = responseData[key];
        }

        handleSuccess(data, json);

        return;
      case 400:
        // Form submission / validation error
        showSnackIcon(L10().formError, success: false);

        // Update field errors
        for (var field in formFields) {
          field.extractErrorMessages(response);
        }

        extractNonFieldErrors(response);
        checkInvalidErrors(response);
      case 401:
        showSnackIcon("401: " + L10().response401, success: false);
      case 403:
        showSnackIcon("403: " + L10().response403, success: false);
      case 404:
        showSnackIcon("404: " + L10().response404, success: false);
      case 405:
        showSnackIcon("405: " + L10().response405, success: false);
      case 500:
        showSnackIcon("500: " + L10().response500, success: false);
      default:
        showSnackIcon(
          "${response.statusCode}: " + L10().responseInvalid,
          success: false,
        );
    }

    setState(() {
      // Refresh the form
    });
  }

  // Construct the internal form widget, based on the provided fields
  Widget buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildForm(),
        ),
        padding: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: COLOR_APP_BAR,
        actions: [
          IconButton(
            icon: Icon(widget.icon),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();

                _save(context);
              }
            },
          ),
        ],
      ),
      body: buildForm(context),
    );
  }
}
