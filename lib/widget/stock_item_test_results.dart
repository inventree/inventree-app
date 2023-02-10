import "package:inventree/app_colors.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/api.dart";
import "package:inventree/widget/progress.dart";

import "package:inventree/l10.dart";

import "package:flutter/material.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";


class StockItemTestResultsWidget extends StatefulWidget {

  const StockItemTestResultsWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemTestResultDisplayState createState() => _StockItemTestResultDisplayState(item);
}


class _StockItemTestResultDisplayState extends RefreshableState<StockItemTestResultsWidget> {

  _StockItemTestResultDisplayState(this.item);

  @override
  String getAppBarTitle(BuildContext context) => L10().testResults;

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    return [
      IconButton(
          icon: FaIcon(FontAwesomeIcons.circlePlus),
          onPressed: () {
              addTestResult(context);
          }
      ),
    ];
  }

  @override
  Future<void> request(BuildContext context) async {
    await item.getTestTemplates();
    await item.getTestResults();
  }

  final InvenTreeStockItem item;

  Future <void> addTestResult(BuildContext context, {String name = "", bool nameIsEditable = true, bool result = false, String value = "", bool valueRequired = false, bool attachmentRequired = false}) async  {

    InvenTreeStockItemTestResult().createForm(
      context,
      L10().testResultAdd,
      data: {
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
          var t = outputs[ii] as InvenTreePartTestTemplate;

          if (result.key == t.key) {
            t.results.add(result);
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

  List<Widget> resultsList() {
    List<Widget> tiles = [];

    tiles.add(
      Card(
        child: ListTile(
          title: Text(item.partName),
          subtitle: Text(item.partDescription),
          leading: InvenTreeAPI().getImage(item.partImage),
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

      bool _required = false;
      String _test = "";
      bool _result = false;
      String _value = "";
      String _notes = "";

      FaIcon _icon = FaIcon(FontAwesomeIcons.circleQuestion, color: COLOR_BLUE);
      bool _valueRequired = false;
      bool _attachmentRequired = false;

      if (item is InvenTreePartTestTemplate) {
        _result = item.passFailStatus();
        _test = item.testName;
        _required = item.required;
        _value = item.latestResult()?.value ?? "";
        _valueRequired = item.requiresValue;
        _attachmentRequired = item.requiresAttachment;
        _notes = item.latestResult()?.notes ?? "";
      } else if (item is InvenTreeStockItemTestResult) {
        _result = item.result;
        _test = item.testName;
        _required = false;
        _value = item.value;
        _notes = item.notes;
      }

      if (_result == true) {
        _icon = FaIcon(FontAwesomeIcons.circleCheck,
          color: COLOR_SUCCESS,
        );
      } else if (_result == false) {
        _icon = FaIcon(FontAwesomeIcons.circleXmark,
          color: COLOR_DANGER,
        );
      }

      tiles.add(ListTile(
        title: Text(_test, style: TextStyle(fontWeight: _required ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(_notes),
        trailing: Text(_value),
        leading: _icon,
        onLongPress: () {
          addTestResult(
              context,
              name: _test,
              nameIsEditable: !_required,
              valueRequired: _valueRequired,
              attachmentRequired: _attachmentRequired
          );
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

  @override
  Widget getBody(BuildContext context) {

    return ListView(
      children: ListTile.divideTiles(
        context: context,
        tiles: resultsList()
      ).toList()
    );
  }
}