

import 'package:InvenTree/barcode.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:InvenTree/widget/stock_item_test_results.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/drawer.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class StockDetailWidget extends StatefulWidget {

  StockDetailWidget(this.item, {Key key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState(item);
}


class _StockItemDisplayState extends RefreshableState<StockDetailWidget> {

  @override
  String getAppBarTitle(BuildContext context) { return "Stock Item"; }

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    return <Widget>[
      // TODO: Hide the 'edit' button if the user does not have permission!!
      IconButton(
        icon: FaIcon(FontAwesomeIcons.edit),
        tooltip: "Edit",
        onPressed: _editStockItemDialog,
      )
    ];
  }

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final _addStockKey = GlobalKey<FormState>();
  final _removeStockKey = GlobalKey<FormState>();
  final _countStockKey = GlobalKey<FormState>();
  final _moveStockKey = GlobalKey<FormState>();
  final _editStockKey = GlobalKey<FormState>();

  _StockItemDisplayState(this.item) {
    // TODO
  }

  final InvenTreeStockItem item;

  @override
  Future<void> request(BuildContext context) async {
    await item.reload(context);
    await item.getTestResults(context);
  }

  void _editStockItem() {
    // TODO - Form for editing stock item
  }

  void _editStockItemDialog() {

    return;
    // TODO - Finish implementing this

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Stock Item"),
          actions: <Widget>[
            FlatButton(
              child: Text("Save"),
              onPressed: () {
                if (_editStockKey.currentState.validate()) {
                  // TODO
                }
              },
            )
          ],
        );
      }
    );
  }

  void _addStock() async {

    Navigator.of(context).pop();

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    // Await response to prevent the button from being pressed multiple times
    var response = await item.addStock(quantity, notes: _notesController.text);
    _notesController.clear();

    // TODO - Handle error cases
    refresh();

    // TODO - Display a snackbar here indicating the action was successful (or otherwise)
  }

  void _addStockDialog() async {

    _quantityController.clear();
    _notesController.clear();

    showFormDialog(context, "Add Stock",
      key: _addStockKey,
      actions: <Widget>[
        FlatButton(
          child: Text("Add"),
            onPressed: () {
              if (_addStockKey.currentState.validate()) _addStock();
            },
        )
      ],
      fields: <Widget> [
        Text("Current stock: ${item.quantity}"),
        QuantityField(
          label: "Add Stock",
          controller: _quantityController,
        ),
        TextFormField(
          decoration: InputDecoration(
            labelText: "Notes",
          ),
          controller: _notesController,
        )
      ],
    );
  }

  void _removeStock() async {
    Navigator.of(context).pop();

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    var response = await item.removeStock(quantity, notes: _notesController.text);
    _notesController.clear();

    // TODO - Handle error cases

    refresh();

    // TODO - Display a snackbar here indicating the action was successful (or otherwise)
  }

  void _removeStockDialog() {

    _quantityController.clear();
    _notesController.clear();

    showFormDialog(context, "Remove Stock",
        key: _removeStockKey,
        actions: <Widget>[
          FlatButton(
            child: Text("Remove"),
            onPressed: () {
              if (_removeStockKey.currentState.validate()) _removeStock();
            },
          )
        ],
        fields: <Widget>[
          Text("Current stock: ${item.quantity}"),
          QuantityField(
            label: "Remove stock",
            controller: _quantityController,
            max: item.quantity,
          ),
          TextFormField(
            decoration: InputDecoration(
              labelText: "Notes",
            ),
            controller: _notesController,
          ),
        ],
    );
  }

  void _countStock() async {

    Navigator.of(context).pop();

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    var response = await item.countStock(quantity, notes: _notesController.text);
    _notesController.clear();

    // TODO - Handle error cases, timeout, etc

    refresh();

    // TODO - Display a snackbar here indicating the action was successful (or otherwise)
  }

  void _countStockDialog() async {

    _quantityController.text = item.quantity.toString();
    _notesController.clear();

    showFormDialog(context, "Count Stock",
      key: _countStockKey,
      actions: <Widget> [
        FlatButton(
          child: Text("Count"),
          onPressed: () {
            if (_countStockKey.currentState.validate()) _countStock();
          },
        )
      ],
      fields: <Widget> [
        QuantityField(
          label: "Count Stock",
          hint: "${item.quantity}",
          controller: _quantityController,
        ),
        TextFormField(
          decoration: InputDecoration(
            labelText: "Notes",
          ),
          controller: _notesController,
        )
      ]
    );
  }


  void _transferStock(BuildContext context, InvenTreeStockLocation location) async {
    Navigator.of(context).pop();

    double quantity = double.parse(_quantityController.text);
    String notes = _notesController.text;

    _quantityController.clear();
    _notesController.clear();

    var response = await item.transferStock(location.pk, quantity: quantity, notes: notes);

    // TODO - Error handling (potentially return false?)
    refresh();

    // TODO - Display a snackbar here indicating the action was successful (or otherwise)

  }

  void _transferStockDialog() async {

    var locations = await InvenTreeStockLocation().list(context);
    final _selectedController = TextEditingController();

    InvenTreeStockLocation selectedLocation;

    _quantityController.text = "${item.quantity}";

    showFormDialog(context, "Transfer Stock",
        key: _moveStockKey,
        actions: <Widget>[
          FlatButton(
            child: Text("Transfer"),
            onPressed: () {
              if (_moveStockKey.currentState.validate()) {
                _moveStockKey.currentState.save();
              }
            },
          )
        ],
        fields: <Widget>[
          QuantityField(
            label: "Quantity",
            controller: _quantityController,
            max: item.quantity,
          ),
          TypeAheadFormField(
              textFieldConfiguration: TextFieldConfiguration(
                  controller: _selectedController,
                  autofocus: true,
                  decoration: InputDecoration(
                      hintText: "Search for location",
                      border: OutlineInputBorder()
                  )
              ),
              suggestionsCallback: (pattern) async {
                var suggestions = List<InvenTreeStockLocation>();

                for (var loc in locations) {
                  if (loc.matchAgainstString(pattern)) {
                    suggestions.add(loc as InvenTreeStockLocation);
                  }
                }

                return suggestions;
              },
              validator: (value) {
                if (selectedLocation == null) {
                  return "Select a location";
                }

                return null;
              },
              onSuggestionSelected: (suggestion) {
                selectedLocation = suggestion as InvenTreeStockLocation;
                _selectedController.text = selectedLocation.pathstring;
              },
              onSaved: (value) {
                _transferStock(context, selectedLocation);
              },
              itemBuilder: (context, suggestion) {
                var location = suggestion as InvenTreeStockLocation;

                return ListTile(
                  title: Text("${location.pathstring}"),
                  subtitle: Text("${location.description}"),
                );
              }
          ),
        ],
    );
  }

  Widget headerTile() {
    return Card(
      child: ListTile(
        title: Text("${item.partName}"),
        subtitle: Text("${item.partDescription}"),
        leading: InvenTreeAPI().getImage(item.partImage),
      )
    );
  }

  /*
   * Construct a list of detail elements about this StockItem.
   * The number of elements may vary depending on the StockItem details
   */
  List<Widget> detailTiles() {
    List<Widget> tiles = [];

    // Image / name / description
    tiles.add(headerTile());

    tiles.add(
      ListTile(
        title: Text("Part"),
        subtitle: Text("${item.partName}"),
        leading: FaIcon(FontAwesomeIcons.shapes),
        onTap: () {
          if (item.partId > 0) {
            InvenTreePart().get(context, item.partId).then((var part) {
              if (part is InvenTreePart) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
              }
            });
          }
        },
      )
    );

    // Location information
    if ((item.locationId > 0) && (item.locationName != null) && (item.locationName.isNotEmpty)) {
      tiles.add(
          ListTile(
            title: Text("Stock Location"),
            subtitle: Text("${item.locationPathString}"),
            leading: FaIcon(FontAwesomeIcons.mapMarkerAlt),
            onTap: () {
              if (item.locationId > 0) {
                InvenTreeStockLocation().get(context, item.locationId).then((var loc) {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => LocationDisplayWidget(loc)));
                });
              }
            },
          )
      );
    } else {
      tiles.add(
          ListTile(
            title: Text("Stock Location"),
            leading: FaIcon(FontAwesomeIcons.mapMarkerAlt),
            subtitle: Text("No location set"),
          )
      );
    }

    // Quantity information
    if (item.isSerialized()) {
      tiles.add(
          ListTile(
            title: Text("Serial Number"),
            leading: FaIcon(FontAwesomeIcons.hashtag),
            trailing: Text("${item.serialNumber}"),
          )
      );
    } else {
      tiles.add(
          ListTile(
            title: Text("Quantity"),
            leading: FaIcon(FontAwesomeIcons.cubes),
            trailing: Text("${item.quantity}"),
          )
      );
    }

    // Supplier part?
    if (item.supplierPartId > 0) {
      tiles.add(
        ListTile(
          title: Text("${item.supplierName}"),
          subtitle: Text("${item.supplierSKU}"),
          leading: FaIcon(FontAwesomeIcons.industry),
          trailing: InvenTreeAPI().getImage(item.supplierImage),
          onTap: null,
        )
      );
    }

    if (item.link.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text("${item.link}"),
          leading: FaIcon(FontAwesomeIcons.link),
          trailing: Text(""),
          onTap: null,
        )
      );
    }

    tiles.add(
        ListTile(
          title: Text("Test Results"),
          leading: FaIcon(FontAwesomeIcons.tasks),
          trailing: Text("${item.testResultCount}"),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => StockItemTestResultsWidget(item)));
          }
        )
    );

    if (item.trackingItemCount > 0) {
      tiles.add(
        ListTile(
          title: Text("History"),
          leading: FaIcon(FontAwesomeIcons.history),
          trailing: Text("${item.trackingItemCount}"),
          onTap: null,
        )
      );
    }

    if (item.notes.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text("Notes"),
          leading: FaIcon(FontAwesomeIcons.stickyNote),
          trailing: Text(""),
          onTap: null,
        )
      );
    }

    return tiles;
  }

  List<Widget> actionTiles() {
    List<Widget> tiles = [];

    tiles.add(headerTile());

    if (!item.isSerialized()) {
      tiles.add(
          ListTile(
              title: Text("Count Stock"),
              leading: FaIcon(FontAwesomeIcons.checkCircle),
              onTap: _countStockDialog,
          )
      );

      tiles.add(
          ListTile(
              title: Text("Remove Stock"),
              leading: FaIcon(FontAwesomeIcons.minusCircle),
              onTap: _removeStockDialog,
          )
      );

      tiles.add(
          ListTile(
              title: Text("Add Stock"),
              leading: FaIcon(FontAwesomeIcons.plusCircle),
              onTap: _addStockDialog,
          )
      );
    }

    tiles.add(
      ListTile(
        title: Text("Transfer Stock"),
        leading: FaIcon(FontAwesomeIcons.exchangeAlt),
        onTap: _transferStockDialog,
      )
    );

    // Scan item into a location
    tiles.add(
      ListTile(
        title: Text("Scan Into Location"),
        leading: FaIcon(FontAwesomeIcons.exchangeAlt),
        trailing: FaIcon(FontAwesomeIcons.qrcode),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => InvenTreeQRView(StockItemScanIntoLocationHandler(item)))
          );
        },
      )
    );

    // Add or remove custom barcode
    if (item.uid.isEmpty) {
      tiles.add(
        ListTile(
          title: Text("Assign Barcode"),
          leading: FaIcon(FontAwesomeIcons.barcode),
          trailing: FaIcon(FontAwesomeIcons.qrcode),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InvenTreeQRView(StockItemBarcodeAssignmentHandler(item)))
            );
          }
        )
      );
    }

    return tiles;
  }

  /*
   * Return a list of context-sensitive action buttons.
   * Not all buttons will be avaialable for a given StockItem,
   * depending on the properties of that StockItem
   */

  /*
  List<SpeedDialChild> actionButtons() {
    var buttons = List<SpeedDialChild>();

    // The following actions only apply if the StockItem is not serialized
    if (!item.isSerialized()) {
      buttons.add(SpeedDialChild(
        child: Icon(FontAwesomeIcons.plusCircle),
        label: "Add Stock",
        onTap: _addStockDialog,
      )
      );

      buttons.add(SpeedDialChild(
        child: Icon(FontAwesomeIcons.minusCircle),
        label: "Remove Stock",
        onTap: _removeStockDialog,
      ),
      );

      buttons.add(SpeedDialChild(
        child: Icon(FontAwesomeIcons.checkCircle),
        label: "Count Stock",
        onTap: _countStockDialog,
      ));
    }

    buttons.add(SpeedDialChild(
      child: Icon(FontAwesomeIcons.exchangeAlt),
      label: "Transfer Stock",
      onTap: _transferStockDialog,
    ));

    return buttons;
  }
   */

  @override
  Widget getBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: tabIndex,
      onTap: onTabSelectionChanged,
      items: const <BottomNavigationBarItem> [
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.infoCircle),
          title: Text("Details"),
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          title: Text("Actions"),
        ),
      ]
    );
  }

  Widget getSelectedWidget(int index) {
    switch (index) {
      case 0:
        return ListView(
          children: detailTiles(),
        );
      case 1:
        return ListView(
          children: actionTiles(),
        );
      default:
        return null;
    }
  }

  @override
  Widget getBody(BuildContext context) {
    return getSelectedWidget(tabIndex);
  }

  /*
  @override
  Widget getFab(BuildContext context) {
    return SpeedDial(
        visible: true,
        animatedIcon: AnimatedIcons.menu_close,
        heroTag: 'stock-item-fab',
        children: actionButtons(),
      );
  }
   */
}