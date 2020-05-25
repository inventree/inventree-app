import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/model.dart';
import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

class StockItemTestResultsWidget extends StatefulWidget {

  StockItemTestResultsWidget(this.item, {Key key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemTestResultDisplayState createState() => _StockItemTestResultDisplayState(item);
}


class _StockItemTestResultDisplayState extends RefreshableState<StockItemTestResultsWidget> {

  final _addResultKey = GlobalKey<FormState>();

  @override
  String getAppBarTitle(BuildContext context) { return "Test Results"; }

  @override
  Future<void> request(BuildContext context) async {
    await item.getTestTemplates(context);
    await item.getTestResults(context);
  }

  final InvenTreeStockItem item;

  _StockItemTestResultDisplayState(this.item);

  void uploadTestResult(String name, bool result, String value, String notes, File attachment) async {

    item.uploadTestResult(
      context,
      name,
      result,
      value: value,
      notes: notes,
      attachment: attachment
    ).then((bool success) {
      if (success) {
        // TODO - Show a SnackBar here!
        refresh();
      } else {
        showErrorDialog(context, "Error", "Could not upload test result to server");
      }
    });
  }

  void addTestResult({String name = '', bool nameIsEditable = true, bool result = false, String value = '', bool valueRequired = false, bool attachmentRequired = false}) async  {

    String _name;
    bool _result;
    String _value;
    String _notes;
    File _attachment;

    showFormDialog(context, "Add Test Data",
      key: _addResultKey,
      actions: <Widget>[
        FlatButton(
          child: Text("Cancel"),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        FlatButton(
          child: Text("Save"),
          onPressed: () {
            if (_addResultKey.currentState.validate()) {
              _addResultKey.currentState.save();
              Navigator.pop(context);
              uploadTestResult(_name, _result, _value, _notes, _attachment);
            }
          },
        )
      ],
      fields: <Widget>[
        StringField(
          label: "Test Name",
          initial: name,
          isEnabled: nameIsEditable,
          onSaved: (value) => _name = value,
        ),
        CheckBoxField(
          label: "Result",
          hint: "Test passed or failed",
          initial: true,
          onSaved: (value) => _result = value,
        ),
        StringField(
          label: "Value",
          initial: value,
          allowEmpty: true,
          onSaved: (value) => _value = value,
          validator: (String value) {
            if (valueRequired && (value == null || value.isEmpty)) {
              return "Value required for this test";
            }
            return null;
          },
        ),
        ImagePickerField(
          label: "Attach Image",
          required: attachmentRequired,
          onSaved: (attachment) => _attachment = attachment,
        ),
        StringField(
          allowEmpty: true,
          label: "Notes",
          onSaved: (value) => _notes = value,
        ),
      ]
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

    var results = getTestResults();

    for (var item in results) {

      bool _required = false;
      String _test;
      bool _result = null;
      String _value;
      String _notes;
      FaIcon _icon = FaIcon(FontAwesomeIcons.questionCircle, color: Color.fromRGBO(0, 0, 250, 1));
      bool _valueRequired = false;
      bool _attachmentRequired = false;

      if (item is InvenTreePartTestTemplate) {
        _result = item.passFailStatus();
        _test = item.testName;
        _required = item.required;
        _value = item.latestResult()?.value ?? '';
        _notes = item.latestResult()?.notes ?? '';
        _valueRequired = item.requiresValue;
        _attachmentRequired = item.requiresAttachment;
      } else if (item is InvenTreeStockItemTestResult) {
        _result = item.result;
        _test = item.testName;
        _required = false;
        _value = item.value;
        _notes = item.notes;
      }

      if (_result == true) {
        _icon = FaIcon(FontAwesomeIcons.checkCircle,
          color: Color.fromRGBO(0, 250, 0, 0.8)
        );
      } else if (_result == false) {
        _icon = FaIcon(FontAwesomeIcons.timesCircle,
          color: Color.fromRGBO(250, 0, 0, 0.8)
        );
      }

      tiles.add(ListTile(
        title: Text(_test, style: TextStyle(fontWeight: _required ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(_value),
        trailing: _icon,
        onLongPress: () {
          addTestResult(
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
        title: Text("No test results"),
      ));
    }

    return tiles;
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: resultsList(),
    );
  }

  List<SpeedDialChild> actionButtons() {

    var buttons = List<SpeedDialChild>();

    buttons.add(SpeedDialChild(
      child: Icon(FontAwesomeIcons.plusCircle),
      label: "Add Test Result",
      onTap: () {
        addTestResult();
      },
    ));

    return buttons;
  }

  @override
  Widget getFab(BuildContext context) {
    return SpeedDial(
      visible: true,
      animatedIcon: AnimatedIcons.menu_close,
      heroTag: 'stock-item-results-tab',
      children: actionButtons(),
    );
  }
}