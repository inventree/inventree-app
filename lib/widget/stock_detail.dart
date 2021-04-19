
import 'dart:io';

import 'package:InvenTree/barcode.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/progress.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:InvenTree/widget/stock_item_test_results.dart';
import 'package:InvenTree/widget/stock_notes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/api.dart';

import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class StockDetailWidget extends StatefulWidget {

  StockDetailWidget(this.item, {Key key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState(item);
}


class _StockItemDisplayState extends RefreshableState<StockDetailWidget> {

  @override
  String getAppBarTitle(BuildContext context) => I18N.of(context).stockItem;

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final _addStockKey = GlobalKey<FormState>();
  final _removeStockKey = GlobalKey<FormState>();
  final _countStockKey = GlobalKey<FormState>();
  final _moveStockKey = GlobalKey<FormState>();
  final _editStockKey = GlobalKey<FormState>();

  _StockItemDisplayState(this.item) {
  }

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    return <Widget>[
      IconButton(
        icon: FaIcon(FontAwesomeIcons.globe),
        onPressed: _openInvenTreePage,
      ),
      // TODO: Hide the 'edit' button if the user does not have permission!!
      /*
      IconButton(
        icon: FaIcon(FontAwesomeIcons.edit),
        tooltip: I18N.of(context).edit,
        onPressed: _editPartDialog,
      )
       */
    ];
  }

  Future<void> _openInvenTreePage() async {
    item.goToInvenTreePage();
  }

  // StockItem object
  final InvenTreeStockItem item;

  // Part object
  InvenTreePart part;

  @override
  Future<void> onBuild(BuildContext context) async {

    // Load part data if not already loaded
    if (part == null) {
      refresh();
    }
  }

  @override
  Future<void> request(BuildContext context) async {
    await item.reload(context);

    // Request part information
    part = await InvenTreePart().get(context, item.partId);

    // Request test results...
    await item.getTestResults(context);
  }

  void _addStock() async {

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    final bool result = await item.addStock(context, quantity, notes: _notesController.text);
    _notesController.clear();

    _stockUpdateMessage(result);

    refresh();
  }

  void _addStockDialog() async {

    _quantityController.clear();
    _notesController.clear();

    showFormDialog( I18N.of(context).addStock,
      key: _addStockKey,
      callback: () {
        _addStock();
      },
      fields: <Widget> [
        Text("Current stock: ${item.quantity}"),
        QuantityField(
          label: I18N.of(context).addStock,
          controller: _quantityController,
        ),
        TextFormField(
          decoration: InputDecoration(
            labelText: I18N.of(context).notes,
          ),
          controller: _notesController,
        )
      ],
    );
  }

  void _stockUpdateMessage(bool result) {

    if (result) {
      showSnackIcon("Stock item updated", success: true);
    }
  }

  void _removeStock() async {

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    final bool result = await item.removeStock(context, quantity, notes: _notesController.text);

    _stockUpdateMessage(result);

    refresh();

  }

  void _removeStockDialog() {

    _quantityController.clear();
    _notesController.clear();

    showFormDialog(I18N.of(context).removeStock,
        key: _removeStockKey,
        callback: () {
          _removeStock();
        },
        fields: <Widget>[
          Text("Current stock: ${item.quantity}"),
          QuantityField(
            label: I18N.of(context).removeStock,
            controller: _quantityController,
            max: item.quantity,
          ),
          TextFormField(
            decoration: InputDecoration(
              labelText: I18N.of(context).notes,
            ),
            controller: _notesController,
          ),
        ],
    );
  }

  void _countStock() async {

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    final bool result = await item.countStock(context, quantity, notes: _notesController.text);

    _stockUpdateMessage(result);

    refresh();
  }

  void _countStockDialog() async {

    _quantityController.text = item.quantityString;
    _notesController.clear();

    showFormDialog(I18N.of(context).countStock,
      key: _countStockKey,
      callback: () {
        _countStock();
      },
      acceptText: I18N.of(context).count,
      fields: <Widget> [
        QuantityField(
          label: I18N.of(context).countStock,
          hint: "${item.quantityString}",
          controller: _quantityController,
        ),
        TextFormField(
          decoration: InputDecoration(
            labelText: I18N.of(context).notes,
          ),
          controller: _notesController,
        )
      ]
    );
  }


  void _unassignBarcode(BuildContext context) async {

    final bool result = await item.update(context, values: {'uid': ''});

    if (result) {
      showSnackIcon(
        I18N.of(context).stockItemUpdateSuccess,
        success: true
      );
    } else {
      showSnackIcon(
        I18N.of(context).stockItemUpdateFailure,
        success: false,
      );
    }

    refresh();
  }


  void _transferStock(BuildContext context, InvenTreeStockLocation location) async {

    double quantity = double.tryParse(_quantityController.text) ?? item.quantity;
    String notes = _notesController.text;

    _quantityController.clear();
    _notesController.clear();

    var result = await item.transferStock(location.pk, quantity: quantity, notes: notes);

    refresh();

    if (result) {
      showSnackIcon("Stock item transferred", success: true);
    }
  }

  void _transferStockDialog() async {

    var locations = await InvenTreeStockLocation().list(context);
    final _selectedController = TextEditingController();

    InvenTreeStockLocation selectedLocation;

    _quantityController.text = "${item.quantityString}";

    showFormDialog(I18N.of(context).transferStock,
        key: _moveStockKey,
        callback: () {
          _transferStock(context, selectedLocation);
        },
        fields: <Widget>[
          QuantityField(
            label: I18N.of(context).quantity,
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
        trailing: Text(
          item.statusLabel(context),
          style: TextStyle(
            color: item.statusColor
          )
        ),
        onTap: () {
          if (item.partId > 0) {
            InvenTreePart().get(context, item.partId).then((var part) {
              if (part is InvenTreePart) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
              }
            });
          }
        },
        //trailing: Text(item.serialOrQuantityDisplay()),
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

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    // Quantity information
    if (item.isSerialized()) {
      tiles.add(
          ListTile(
            title: Text(I18N.of(context).serialNumber),
            leading: FaIcon(FontAwesomeIcons.hashtag),
            trailing: Text("${item.serialNumber}"),
          )
      );
    } else {
      tiles.add(
          ListTile(
            title: Text(I18N.of(context).quantity),
            leading: FaIcon(FontAwesomeIcons.cubes),
            trailing: Text("${item.quantityString}"),
          )
      );
    }

    // Location information
    if ((item.locationId > 0) && (item.locationName != null) && (item.locationName.isNotEmpty)) {
      tiles.add(
          ListTile(
            title: Text(I18N.of(context).stockLocation),
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
            title: Text(I18N.of(context).stockLocation),
            leading: FaIcon(FontAwesomeIcons.mapMarkerAlt),
            subtitle: Text("No location set"),
          )
      );
    }

    // Stocktake?

    // Supplier part?
    // TODO: Display supplier part info page?
    if (false && item.supplierPartId > 0) {
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

    if ((item.testResultCount > 0) || (part != null && part.isTrackable)) {
      tiles.add(
          ListTile(
              title: Text(I18N.of(context).testResults),
              leading: FaIcon(FontAwesomeIcons.tasks),
              trailing: Text("${item.testResultCount}"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => StockItemTestResultsWidget(item))
                ).then((context) {
                  refresh();
                });
              }
          )
      );
    }

    // TODO - Re-enable stock item history display
    if (false && item.trackingItemCount > 0) {
      tiles.add(
        ListTile(
          title: Text(I18N.of(context).history),
          leading: FaIcon(FontAwesomeIcons.history),
          trailing: Text("${item.trackingItemCount}"),
          onTap: () {
            // TODO: Load tracking history

            // TODO: Push tracking history page to the route

          },
        )
      );
    }

    if (item.notes.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(I18N.of(context).notes),
          leading: FaIcon(FontAwesomeIcons.stickyNote),
          trailing: Text(""),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StockNotesWidget(item))
            );
            // TODO: Load notes in markdown viewer widget
            // TODO: Make this widget editable?
          }
        )
      );
    }

    return tiles;
  }

  List<Widget> actionTiles() {
    List<Widget> tiles = [];

    tiles.add(headerTile());

    // First check that the user has the required permissions to adjust stock
    if (!InvenTreeAPI().checkPermission('stock', 'change')) {
      tiles.add(
        ListTile(
          title: Text("Permission Required"),
          leading: FaIcon(FontAwesomeIcons.userTimes)
        )
      );

      tiles.add(
        ListTile(
          subtitle: Text("Your account does not have permission to perform stock adjustments"),
        )
      );

      return tiles;
    }

    if (!item.isSerialized()) {
      tiles.add(
          ListTile(
              title: Text(I18N.of(context).countStock),
              leading: FaIcon(FontAwesomeIcons.checkCircle),
              onTap: _countStockDialog,
          )
      );

      tiles.add(
          ListTile(
              title: Text(I18N.of(context).removeStock),
              leading: FaIcon(FontAwesomeIcons.minusCircle),
              onTap: _removeStockDialog,
          )
      );

      tiles.add(
          ListTile(
              title: Text(I18N.of(context).addStock),
              leading: FaIcon(FontAwesomeIcons.plusCircle),
              onTap: _addStockDialog,
          )
      );
    }

    tiles.add(
      ListTile(
        title: Text(I18N.of(context).transferStock),
        leading: FaIcon(FontAwesomeIcons.exchangeAlt),
        onTap: _transferStockDialog,
      )
    );

    // Scan item into a location
    tiles.add(
      ListTile(
        title: Text(I18N.of(context).scanIntoLocation),
        leading: FaIcon(FontAwesomeIcons.exchangeAlt),
        trailing: FaIcon(FontAwesomeIcons.qrcode),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => InvenTreeQRView(StockItemScanIntoLocationHandler(item)))
          ).then((context) {
            refresh();
          });
        },
      )
    );

    // Add or remove custom barcode
    if (item.uid.isEmpty) {
      tiles.add(
        ListTile(
          title: Text(I18N.of(context).barcodeAssign),
          leading: FaIcon(FontAwesomeIcons.barcode),
          trailing: FaIcon(FontAwesomeIcons.qrcode),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InvenTreeQRView(StockItemBarcodeAssignmentHandler(item)))
            ).then((context) {
              refresh();
            });
          }
        )
      );
    } else {
      tiles.add(
        ListTile(
          title: Text(I18N.of(context).barcodeUnassign),
          leading: FaIcon(FontAwesomeIcons.barcode),
          onTap: () {
            _unassignBarcode(context);
          }
        )
      );
    }

    return tiles;
  }

  @override
  Widget getBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: tabIndex,
      onTap: onTabSelectionChanged,
      items: <BottomNavigationBarItem> [
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.infoCircle),
          title: Text(I18N.of(context).details),
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          title: Text(I18N.of(context).actions),
        ),
      ]
    );
  }

  Widget getSelectedWidget(int index) {
    switch (index) {
      case 0:
        return ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: detailTiles()
          ).toList(),
        );
      case 1:
        return ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: actionTiles()
          ).toList()
        );
      default:
        return null;
    }
  }

  @override
  Widget getBody(BuildContext context) {
    return getSelectedWidget(tabIndex);
  }
}