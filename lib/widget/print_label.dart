

import "package:flutter/cupertino.dart";
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
    super.onBuild(context);
  }

  @override
  Future<void> request(BuildContext context) async {

    print("label widget:");

    return;
  }

  @override
  Widget getBody(BuildContext context) {
    return Container();
  }
}