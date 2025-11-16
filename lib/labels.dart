import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:inventree/preferences.dart";
import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Custom form handler for label printing.
 * Required to manage dynamic form fields.
 */
class LabelFormWidgetState extends APIFormWidgetState {
  LabelFormWidgetState() : super();

  @override
  List<APIFormField> get formFields {
    final baseFields = super.formFields;

    // TODO: Inject dynamic fields based on selected plugin

    return baseFields;
  }

  @override
  void onValueChanged(String field, dynamic value) {
    // TODO: Selected plugin changed

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
    "api/label/print/",
    baseFields,
    method: "POST",
    formHandler: formHandler,
  );
}
