import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/print_label.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Discover which label templates are available for a given item
 */
Future<List<Map<String, dynamic>>> getLabelTemplates(
    String labelType,
    Map<String, String> data,
    ) async {
  if (!InvenTreeAPI().isConnected() ||
      !InvenTreeAPI().supportsMixin("labels")) {
    return [];
  }

  // Filter by active plugins
  data["enabled"] = "true";

  String url = "/label/template/";

  if (InvenTreeAPI().supportsModernLabelPrinting) {
    data["model_type"] = labelType;
  } else {
    // Legacy label printing API endpoint
    url = "/label/${labelType}/";
  }

  List<Map<String, dynamic>> labels = [];

  await InvenTreeAPI().get(url, params: data).then((APIResponse response) {
    if (response.isValid() && response.statusCode == 200) {
      for (var label in response.resultsList()) {
        if (label is Map<String, dynamic>) {
          labels.add(label);
        }
      }
    }
  });

  return labels;
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
    showSnackIcon(
      "Label printing not supported by server",
      success: false,
    );
    return;
  }

  // Fetch default values for label printing

  // Default template
  final defaultTemplates = await InvenTreeSettingsManager().getValue(INV_LABEL_DEFAULT_TEMPLATES, null);
  int? defaultTemplate;

  if (defaultTemplates != null && defaultTemplates is Map<String, dynamic>) {
    defaultTemplate = defaultTemplates[labelType] as int?;
  }

  // Default plugin
  final defaultPlugin = await InvenTreeSettingsManager().getValue(INV_LABEL_DEFAULT_PLUGIN, null);

  // Specify a default list of fields for printing
  // The selected plugin may optionally extend this list of fields dynamically
  Map<String, Map<String, dynamic>> baseFields = {
    "template": {
      "default": defaultTemplate,
      "filters": {
        "enabled": true,
        "model_type": labelType,
        "items": instanceId.toString(),
      }
    },
    "plugin": {
      "default": defaultPlugin,
      "filters": {
        "enabled": true,
        "mixin": "labels"
      }
    },
    "items": {
      "hidden": true,
      "value": [instanceId],
    }
  };

  launchApiForm(context, L10().printLabel, "api/label/print/", baseFields, method: 'POST');
}

