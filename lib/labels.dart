import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
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

  // Fetch list of available label templates
  List<Map<String, dynamic>> labels = [];

  await getLabelTemplates(labelType, {"items": instanceId.toString()}).then((templates) {
    labels = templates;
  });

  print("labels: ${labels.toString()}");

  if (labels.isEmpty) {
    showSnackIcon(
      "No label printing templates available",
      success: false,
    );
    return;
  }

  // Find a list of available plugins which support label printing
  final plugins = InvenTreeAPI().getPlugins(mixin: "labels");

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PrintLabelWidget(
        labelType: labelType,
        instanceId: instanceId,
        labelTemplates: labels,
        labelPlugins: [...plugins],
      )
    )
  );

  /**
  dynamic initial_label;
  dynamic initial_plugin;




  if (label_options.length == 1) {
    initial_label = label_options.first["value"];
  }

  // Construct list of available plugins
  for (var plugin in plugins) {
    plugin_options.add({"display_name": plugin.humanName, "value": plugin.key});
  }

  String selectedPlugin = await InvenTreeAPI().getUserSetting(
    "LABEL_DEFAULT_PRINTER",
  );

  if (selectedPlugin.isNotEmpty) {
    initial_plugin = selectedPlugin;
  } else if (plugin_options.length == 1) {
    initial_plugin = plugin_options.first["value"];
  }

  Map<String, dynamic> fields = {
    "label": {
      "label": L10().labelTemplate,
      "type": "choice",
      "value": initial_label,
      "choices": label_options,
      "required": true,
    },
    "plugin": {
      "label": L10().pluginPrinter,
      "type": "choice",
      "value": initial_plugin,
      "choices": plugin_options,
      "required": true,
    },
  };

  launchApiForm(
    context,
    L10().printLabel,
    "",
    fields,
    icon: TablerIcons.printer,
    validate: (Map<String, dynamic> data) {
      final template = data["label"];
      final plugin = data["plugin"];

      if (template == null) {
        showSnackIcon(L10().labelSelectTemplate, success: false);
        return false;
      }

      if (plugin == null) {
        showSnackIcon(L10().labelSelectPrinter, success: false);
        return false;
      }

      return true;
    },
    onSuccess: (Map<String, dynamic> data) async {
      int labelId = (data["label"] ?? -1) as int;
      var pluginKey = data["plugin"];

      bool result = false;

      if (labelId != -1 && pluginKey != null) {
        showLoadingOverlay();

        if (InvenTreeAPI().supportsModernLabelPrinting) {
          // Modern label printing API uses a POST request to a single API endpoint.
          await InvenTreeAPI()
              .post(
                "/label/print/",
                body: {
                  "plugin": pluginKey,
                  "template": labelId,
                  "items": [instanceId],
                },
              )
              .then((APIResponse response) {
                if (response.isValid() &&
                    response.statusCode >= 200 &&
                    response.statusCode <= 201) {
                  var data = response.asMap();

                  if (data.containsKey("output")) {
                    String? label_file = (data["output"]) as String?;

                    if (label_file != null && label_file.isNotEmpty) {
                      // Attempt to open generated file
                      InvenTreeAPI().downloadFile(label_file);
                    }

                    result = true;
                  }
                }
              });
        } else {
          // Legacy label printing API
          // Uses a GET request to a specially formed URL which depends on the parameters
          String url =
              "/label/${labelType}/${labelId}/print/?${labelQuery}&plugin=${pluginKey}";
          await InvenTreeAPI().get(url).then((APIResponse response) {
            if (response.isValid() && response.statusCode == 200) {
              var data = response.asMap();
              if (data.containsKey("file")) {
                var label_file = (data["file"] ?? "") as String;

                // Attempt to open remote file
                InvenTreeAPI().downloadFile(label_file);
                result = true;
              }
            }
          });
        }

        hideLoadingOverlay();

        if (result) {
          showSnackIcon(L10().printLabelSuccess, success: true);
        } else {
          showSnackIcon(L10().printLabelFailure, success: false);
        }
      }
    },
  );
  */
}

