import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:inventree/preferences.dart";
import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";

const String PRINT_LABEL_URL = "api/label/print/";

/*
 * Custom form handler for label printing.
 * Required to manage dynamic form fields.
 */
class LabelFormWidgetState extends APIFormWidgetState {
  LabelFormWidgetState() : super();

  List<APIFormField> dynamicFields = [];

  @override
  List<APIFormField> get formFields {
    final baseFields = super.formFields;

    // TODO: Inject dynamic fields based on selected plugin

    return [...baseFields, ...dynamicFields];
  }

  @override
  void onValueChanged(String field, dynamic value) {
    if (field == "plugin") {
      onPluginChanged(value.toString());
    }
  }

  /*
   * Re-fetch printing options when the plugin changes
   */
  Future<void> onPluginChanged(String key) async {

    showLoadingOverlay();

    InvenTreeAPI().options(
        PRINT_LABEL_URL,
        params: {
          "plugin": key
        }
    ).then((APIResponse response) {
      if (response.isValid()) {
        updateFields(response);
        hideLoadingOverlay();
      }
    });
  }

  /*
 * Callback when the server responds with printing options,
 * based on the selected printing plugin
 */
  Future<void> updateFields(APIResponse response) async {
    Map<String, dynamic> printingFields = extractFields(response);

    // Find only the fields which are not in the "base" fields
    List<APIFormField> uniqueFields = [];

    final baseFields = super.formFields;

    for (String key in printingFields.keys) {
      if (super.formFields.any((field) => field.name == key)) {
        continue;
      }

      dynamic data = printingFields[key];

      Map<String, dynamic> fieldData = {};

      if (data is Map) {
        fieldData = Map<String, dynamic>.from(data);
      }

      APIFormField field = APIFormField(key, fieldData);
      field.definition = extractFieldDefinition(printingFields, field.lookupPath);

      if (field.type == "dependent field") {
        // Dependent fields must be handled separately

        // TODO: This should be refactored into api_form.dart
        dynamic child = field.definition["child"];

        if (child != null && child is Map) {
          Map<String, dynamic> child_map = child as Map<String, dynamic>;
          dynamic nested_children = child_map["children"];

          if (nested_children != null && nested_children is Map) {
            Map<String, dynamic> nested_child_map = nested_children as Map<String, dynamic>;

            for (var field_key in nested_child_map.keys) {
              field = APIFormField(field_key, nested_child_map);
              field.definition = extractFieldDefinition(nested_child_map, field_key);
              uniqueFields.add(field);
            }
          }
        }

      } else {
        // This is a "standard" (non-nested) field
        uniqueFields.add(field);
      }
    }

    if (mounted) {
      setState(() {
        dynamicFields = uniqueFields;
      });
    }
  }
}



/*
 * Select a particular label, from a provided list of options,
 * and print against the selected instances.
 *
 */
Future<void> selectAndPrintLabel(
  BuildContext context,
  String labelType,
  int instanceId,
) async {
  if (!InvenTreeAPI().isConnected()) {
    return;
  }

  if (!InvenTreeAPI().supportsModernLabelPrinting) {
    // Legacy label printing API not supported
    showSnackIcon("Label printing not supported by server", success: false);
    return;
  }

  // Fetch default values for label printing

  // Default template
  final defaultTemplates = await InvenTreeSettingsManager().getValue(
    INV_LABEL_DEFAULT_TEMPLATES,
    null,
  );
  int? defaultTemplate;

  if (defaultTemplates != null && defaultTemplates is Map<String, dynamic>) {
    defaultTemplate = defaultTemplates[labelType] as int?;
  }

  // Default plugin
  final defaultPlugin = await InvenTreeSettingsManager().getValue(
    INV_LABEL_DEFAULT_PLUGIN,
    null,
  );

  // Specify a default list of fields for printing
  // The selected plugin may optionally extend this list of fields dynamically
  Map<String, Map<String, dynamic>> baseFields = {
    "template": {
      "default": defaultTemplate,
      "filters": {
        "enabled": true,
        "model_type": labelType,
        "items": instanceId.toString(),
      },
    },
    "plugin": {
      "default": defaultPlugin,
      "pk_field": "key",
      "filters": {"enabled": true, "mixin": "labels"},
    },
    "items": {
      "hidden": true,
      "value": [instanceId],
    },
  };

  final formHandler = LabelFormWidgetState();

  launchApiForm(
    context,
    L10().printLabel,
    PRINT_LABEL_URL,
    baseFields,
    method: "POST",
    formHandler: formHandler,
  );
}
