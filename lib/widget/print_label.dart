

import "package:dropdown_search/dropdown_search.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/refreshable_state.dart";

class PrintLabelWidget extends StatefulWidget {
  const PrintLabelWidget({
    required this.labelTemplates,
    required this.labelPlugins,
    required this.instanceId,
    required this.labelType,
    Key? key}
  ) : super(key: key);

  final int instanceId;
  final String labelType;
  final List<Map<String, dynamic>> labelTemplates;
  final List<InvenTreePlugin> labelPlugins;

  @override
  _PrintLabelWidgetState createState() => _PrintLabelWidgetState();
}


class _PrintLabelWidgetState extends RefreshableState<PrintLabelWidget> {

  @override
  String getAppBarTitle() => L10().printLabel;

  dynamic initial_label;
  dynamic initial_plugin;

  List<Map<String, dynamic>> label_options = [];
  List<Map<String, dynamic>> plugin_options = [];

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    // TODO: Add actions here

    return actions;
  }

  @override
  Future<void> onBuild(BuildContext context) async {

    // Construct a list of available label templates
    // Construct list of available label templates
    for (var label in widget.labelTemplates) {
      String name = (label["name"] ?? "").toString();
      String description = (label["description"] ?? "").toString();

      if (description.isNotEmpty) {
        name += " - ${description}";
      }

      int pk = (label["pk"] ?? -1) as int;

      if (name.isNotEmpty && pk > 0) {
        label_options.add({"display_name": name, "value": pk});
      }
    }

    // Construct list of available plugins
    for (var plugin in widget.labelPlugins) {
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

    super.onBuild(context);
  }

  @override
  Future<void> request(BuildContext context) async {

    print("label widget:");

    return;
  }

  @override
  Widget getBody(BuildContext context) {

    const double headerSize = 16;

    return Container(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10().labelSelectTemplate, style: TextStyle(fontSize: headerSize, fontWeight: FontWeight.bold)),
            // Select label template
            DropdownSearch<dynamic>(
              popupProps: PopupProps.bottomSheet(
                showSelectedItems: false,
                searchFieldProps: TextFieldProps(autofocus: true),
              ),
              selectedItem: initial_label,
              items: label_options,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: L10().labelTemplate,
                  hintText: L10().labelSelectTemplate
                )
              ),
              onChanged: null,
              clearButtonProps: ClearButtonProps(isVisible: false),
              itemAsString: (dynamic item) => item["display_name"].toString(),
              onSaved: (item) {
                // TODO
              },
            ),
            Divider(height: 10),
            Text(
              L10().labelSelectDriver,
              style: TextStyle(fontSize: headerSize, fontWeight: FontWeight.bold),
            ),
            // Select label printer plugin
            DropdownSearch<dynamic>(
              popupProps: PopupProps.bottomSheet(
                showSelectedItems: false,
                searchFieldProps: TextFieldProps(autofocus: true),
              ),
              selectedItem: initial_plugin,
              items: plugin_options,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: L10().labelDriver,
                  hintText: L10().labelSelectDriver
                )
              ),
              onChanged: null,
              clearButtonProps: ClearButtonProps(isVisible: false),
              itemAsString: (dynamic item) => item["display_name"].toString(),
              onSaved: (item) {
                // TODO
              },
            )
          ]
        )
      )
    );
  }
}