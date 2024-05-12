import "package:flutter/cupertino.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/api.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Select a particular label, from a provided list of options,
 * and print against the selected instances.
 *
 */
Future<void> selectAndPrintLabel(
  BuildContext context,
  List<Map<String, dynamic>> labels,
  int instanceId,
  String labelType,
  String labelQuery,
) async {

  if (!InvenTreeAPI().isConnected()) {
    return;
  }

  // Find a list of available plugins which support label printing
  var plugins = InvenTreeAPI().getPlugins(mixin: "labels");

  dynamic initial_label;
  dynamic initial_plugin;

  List<Map<String, dynamic>> label_options = [];
  List<Map<String, dynamic>> plugin_options = [];

  // Construct list of available label templates
  for (var label in labels) {
    String name = (label["name"] ?? "").toString();
    String description = (label["description"] ?? "").toString();

    if (description.isNotEmpty) {
      name += " - ${description}";
    }

    int pk = (label["pk"] ?? -1) as int;

    if (name.isNotEmpty && pk > 0) {
      label_options.add({
        "display_name": name,
        "value": pk,
      });
    }
  }

  if (label_options.length == 1) {
    initial_label = label_options.first["value"];
  }

  // Construct list of available plugins
  for (var plugin in plugins) {
    plugin_options.add({
      "display_name": plugin.humanName,
      "value": InvenTreeAPI().supportsModenLabelPrinting ? plugin.pk : plugin.key
    });
  }

  if (plugin_options.length == 1) {
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
    }
  };

  launchApiForm(
    context,
    L10().printLabel,
    "",
    fields,
    icon: FontAwesomeIcons.print,
    onSuccess: (Map<String, dynamic> data) async {
      int labelId = (data["label"] ?? -1) as int;
      var pluginKey = data["plugin"];

      bool result = false;

      if (labelId != -1 && pluginKey != null) {

        showLoadingOverlay(context);

        if (InvenTreeAPI().supportsModenLabelPrinting) {

          // Modern label printing API uses a POST request to a single API endpoint.
          await InvenTreeAPI().post(
            "/label/print/",
            body: {
              "plugin": pluginKey,
              "template": labelId,
              "items": [instanceId]
            }
          ).then((APIResponse response) {
            hideLoadingOverlay();

            if (response.isValid() && response.statusCode >= 200 &&
                response.statusCode <= 201) {
              var data = response.asMap();

              if (data.containsKey("output")) {
                var label_file = (data["output"] ?? "") as String;

                // Attempt to open generated file
                InvenTreeAPI().downloadFile(label_file);
                result = true;
              }
            }
        });
      } else {
          // Legacy label printing API
          // Uses a GET request to a specially formed URL which depends on the parameters
          String url = "/label/${labelType}/${labelId}/print/?${labelQuery}&plugin=${pluginKey}";
          await InvenTreeAPI().get(url).then((APIResponse response) {
            hideLoadingOverlay();
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

      if (result) {
        showSnackIcon(
          L10().printLabelSuccess,
          success: true
        );
      } else {
        showSnackIcon(
          L10().printLabelFailure,
          success: false,
        );
      }
    }
  });
}


/*
 * Discover which label templates are available for a given item
 */
Future<List<Map<String, dynamic>>> getLabelTemplates(
  String labelType,
  Map<String, String> data,
) async {

  if (!InvenTreeAPI().isConnected() || !InvenTreeAPI().supportsMixin("labels")) {
    return [];
  }

  // Filter by active plugins
  data["enabled"] = "true";

  String url = "/label/template/";

  if (InvenTreeAPI().supportsModenLabelPrinting) {
    data["model_type"] = labelType;
  } else {
    // Legacy label printing API endpoint
    url = "/label/${labelType}/";
  }

  List<Map<String, dynamic>> labels = [];

  await InvenTreeAPI().get(
    url,
    params: data,
  ).then((APIResponse response) {
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