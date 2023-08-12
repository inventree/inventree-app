import "package:flutter/cupertino.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/api.dart";
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

  if (!InvenTreeAPI().isConnected() || !InvenTreeAPI().supportsMixin("labels")) {
    return [];
  }

  // Filter by active plugins
  data["enabled"] = "true";

  List<Map<String, dynamic>> labels = [];

  await InvenTreeAPI().get(
    "/label/${labelType}/",
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


/*
 * Select a particular label, from a provided list of options,
 * and print against the selected instances.
 */
Future<void> selectAndPrintLabel(
    BuildContext context,
    List<Map<String, dynamic>> labels,
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
      "value": plugin.key
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
      String pluginKey = (data["plugin"] ?? "") as String;

      if (labelId != -1 && pluginKey.isNotEmpty) {
        String url = "/label/${labelType}/${labelId}/print/?${labelQuery}&plugin=${pluginKey}";

        showLoadingOverlay(context);

        InvenTreeAPI().get(url).then((APIResponse response) {
          hideLoadingOverlay();
          if (response.isValid() && response.statusCode == 200) {

            var data = response.asMap();

            if (data.containsKey("file")) {
              var label_file = (data["file"] ?? "") as String;

              // Attempt to open remote file
              InvenTreeAPI().downloadFile(label_file);
            } else {
              showSnackIcon(
                  L10().printLabelSuccess,
                  success: true
              );
            }
          } else {
            showSnackIcon(
              L10().printLabelFailure,
              success: false,
            );
          }
        });
      }
    },
  );
}