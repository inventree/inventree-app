import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/model.dart";

import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";


class StockItemTestResultsWidget extends StatefulWidget {

  const StockItemTestResultsWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemTestResultDisplayState createState() => _StockItemTestResultDisplayState(item);
}


class _StockItemTestResultDisplayState extends RefreshableState<StockItemTestResultsWidget> {

  _StockItemTestResultDisplayState(this.item);

  @override
  String getAppBarTitle() => L10().testResults;

  @override
  List<Widget> appBarActions(BuildContext context) => [];

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreeStockItemTestResult().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.circle_plus),
          label: L10().testResultAdd,
          onTap: () {
            addTestResult(context);
          }
        )
      );
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    await item.getTestTemplates();
    await item.getTestResults();
  }

  final InvenTreeStockItem item;

  Future <void> addTestResult(BuildContext context, {int templateId = 0, String name = "", bool nameIsEditable = true, bool result = false, String value = "", bool valueRequired = false, bool attachmentRequired = false}) async  {

    Map<String, Map<String, dynamic>> fields = InvenTreeStockItemTestResult().formFields();

    // Add additional filters
    fields["template"]?["filters"]?["part"] = "${item.partId}";

    InvenTreeStockItemTestResult().createForm(
      context,
      L10().testResultAdd,
      fields: fields,
      data: {
        "template": "${templateId}",
        "stock_item": "${item.pk}",
        "test": "${name}",
      },
      onSuccess: (data) {
        refresh(context);
      },
      fileField: "attachment",
    );
  }

  // Squish together templates and results
  List<InvenTreeModel> getTestResults() {
    var templates = item.testTemplates;
    var results = item.testResults;

    List<InvenTreeModel> outputs = [];

    // Add each template to the list
    for (var t in templates) {
      outputs.add(t);
    }

    // Add each result (compare to existing items / templates
    for (var result in results) {
      bool match = false;

      for (var ii = 0; ii < outputs.length; ii++) {

        // Check against templates
        if (outputs[ii] is InvenTreePartTestTemplate) {
          var template = outputs[ii] as InvenTreePartTestTemplate;

          // Match the result to a template
          if (result.templateId == template.pk || result.key == template.key) {
            template.results.add(result);
            match = true;
            break;
          }
        } else if (outputs[ii] is InvenTreeStockItemTestResult) {
          var r = outputs[ii] as InvenTreeStockItemTestResult;

          if (r.key == result.key) {
            // Overwrite with a newer result
            outputs[ii] = result;
            match = true;
            break;
          }
        }
      }

      if (!match) {
        outputs.add(result);
      }
    }

    return outputs;
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    tiles.add(
      Card(
        child: ListTile(
          title: Text(item.partName),
          subtitle: Text(item.partDescription),
          leading: InvenTreeAPI().getThumbnail(item.partImage),
        )
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().testResults,
          style: TextStyle(fontWeight: FontWeight.bold)
        )
      )
    );

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    var results = getTestResults();

    if (results.isEmpty) {
      tiles.add(ListTile(
        title: Text(L10().testResultNone),
        subtitle: Text(L10().testResultNoneDetail),
      ));

      return tiles;
    }

    for (var item in results) {

      bool _hasResult = false;
      bool _required = false;
      String _test = "";
      int _templateId = 0;
      bool _result = false;
      String _value = "";
      String _date = "";

      Widget _icon = Icon(TablerIcons.help_circle, color: Colors.lightBlue);
      bool _valueRequired = false;
      bool _attachmentRequired = false;

      if (item is InvenTreePartTestTemplate) {
        _result = item.passFailStatus();
        _test = item.testName;
        _templateId = item.pk;
        _required = item.required;
        _value = item.latestResult()?.value ?? L10().noResults;
        _valueRequired = item.requiresValue;
        _attachmentRequired = item.requiresAttachment;
        _date = item.latestResult()?.date ?? "";
        _hasResult = item.latestResult() != null;
      } else if (item is InvenTreeStockItemTestResult) {
        _result = item.result;
        _test = item.testName;
        _templateId = item.templateId;
        _date = item.date;
        _required = false;
        _value = item.value;
        _hasResult = true;
      }

      if (!_hasResult) {
        _icon = Icon(TablerIcons.help_circle, color: Colors.blue);
      } else if (_result == true) {
        _icon = Icon(TablerIcons.circle_check, color: COLOR_SUCCESS);
      } else if (_result == false) {
        _icon = Icon(TablerIcons.circle_x, color: COLOR_DANGER);
      }

      tiles.add(ListTile(
        title: Text(_test, style: TextStyle(
          fontWeight: _required ? FontWeight.bold : FontWeight.normal,
          fontStyle: _hasResult ? FontStyle.normal : FontStyle.italic
        )),
        subtitle: Text(_value),
        trailing: Text(_date),
        leading: _icon,
        onTap: () {
          if (InvenTreeStockItemTestResult().canCreate) {
            addTestResult(
                context,
                name: _test,
                templateId: _templateId,
                nameIsEditable: !_required,
                valueRequired: _valueRequired,
                attachmentRequired: _attachmentRequired
            );
          }
        }
      ));
    }

    if (tiles.isEmpty) {
      tiles.add(ListTile(
        title: Text(L10().testResultNone),
      ));
    }

    return tiles;
  }
}