import 'package:inventree/app_colors.dart';
import 'package:inventree/barcode.dart';
import 'package:inventree/inventree/model.dart';
import 'package:inventree/inventree/stock.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/widget/dialogs.dart';
import 'package:inventree/widget/fields.dart';
import 'package:inventree/widget/location_display.dart';
import 'package:inventree/widget/part_detail.dart';
import 'package:inventree/widget/progress.dart';
import 'package:inventree/widget/refreshable_state.dart';
import 'package:inventree/widget/snacks.dart';
import 'package:inventree/widget/stock_item_test_results.dart';
import 'package:inventree/widget/stock_notes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:inventree/l10.dart';

import 'package:inventree/api.dart';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class StockDetailWidget extends StatefulWidget {

  StockDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState(item);
}


class _StockItemDisplayState extends RefreshableState<StockDetailWidget> {

  @override
  String getAppBarTitle(BuildContext context) => L10().stockItem;

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final _addStockKey = GlobalKey<FormState>();
  final _removeStockKey = GlobalKey<FormState>();
  final _countStockKey = GlobalKey<FormState>();
  final _moveStockKey = GlobalKey<FormState>();

  _StockItemDisplayState(this.item);

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission('stock', 'view')) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.globe),
          onPressed: _openInvenTreePage,
        )
      );
    }

    if (InvenTreeAPI().checkPermission('stock', 'change')) {
      actions.add(
          IconButton(
            icon: FaIcon(FontAwesomeIcons.edit),
            tooltip: L10().edit,
            onPressed: () { _editStockItem(context); },
          )
      );
    }

    return actions;
  }

  Future<void> _openInvenTreePage() async {
    item.goToInvenTreePage();
  }

  // StockItem object
  final InvenTreeStockItem item;

  // Part object
  InvenTreePart? part;

  @override
  Future<void> onBuild(BuildContext context) async {

    // Load part data if not already loaded
    if (part == null) {
      refresh();
    }
  }

  @override
  Future<void> request() async {
    await item.reload();

    // Request part information
    part = await InvenTreePart().get(item.partId) as InvenTreePart;

    // Request test results...
    await item.getTestResults();
  }

  void _editStockItem(BuildContext context) async {

    var fields = InvenTreeStockItem().formFields();

    // Some fields we don't want to edit!
    fields.remove("part");
    fields.remove("quantity");
    fields.remove("location");

    item.editForm(
      context,
      L10().editItem,
      fields: fields,
      onSuccess: (data) async {
        refresh();
      }
    );

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

    showFormDialog( L10().addStock,
      key: _addStockKey,
      callback: () {
        _addStock();
      },
      fields: <Widget> [
        Text("Current stock: ${item.quantity}"),
        QuantityField(
          label: L10().addStock,
          controller: _quantityController,
        ),
        TextFormField(
          decoration: InputDecoration(
            labelText: L10().notes,
          ),
          controller: _notesController,
        )
      ],
    );
  }

  void _stockUpdateMessage(bool result) {

    if (result) {
      showSnackIcon(L10().stockItemUpdated, success: true);
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

    showFormDialog(L10().removeStock,
        key: _removeStockKey,
        callback: () {
          _removeStock();
        },
        fields: <Widget>[
          Text("Current stock: ${item.quantity}"),
          QuantityField(
            label: L10().removeStock,
            controller: _quantityController,
            max: item.quantity,
          ),
          TextFormField(
            decoration: InputDecoration(
              labelText: L10().notes,
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

    showFormDialog(L10().countStock,
      key: _countStockKey,
      callback: () {
        _countStock();
      },
      acceptText: L10().count,
      fields: <Widget> [
        QuantityField(
          label: L10().countStock,
          hint: "${item.quantityString}",
          controller: _quantityController,
        ),
        TextFormField(
          decoration: InputDecoration(
            labelText: L10().notes,
          ),
          controller: _notesController,
        )
      ]
    );
  }


  void _unassignBarcode(BuildContext context) async {

    final bool result = await item.update(values: {'uid': ''});

    if (result) {
      showSnackIcon(
        L10().stockItemUpdateSuccess,
        success: true
      );
    } else {
      showSnackIcon(
        L10().stockItemUpdateFailure,
        success: false,
      );
    }

    refresh();
  }


  void _transferStock(int locationId) async {

    double quantity = double.tryParse(_quantityController.text) ?? item.quantity;
    String notes = _notesController.text;

    _quantityController.clear();
    _notesController.clear();

    var result = await item.transferStock(locationId, quantity: quantity, notes: notes);

    refresh();

    if (result) {
      showSnackIcon(L10().stockItemTransferred, success: true);
    }
  }

  void _transferStockDialog(BuildContext context) async {

    int? location_pk;

    _quantityController.text = "${item.quantityString}";

    showFormDialog(L10().transferStock,
        key: _moveStockKey,
        callback: () {
          var _pk = location_pk;

          if (_pk != null) {
            _transferStock(_pk);
          }
        },
        fields: <Widget>[
          QuantityField(
            label: L10().quantity,
            controller: _quantityController,
            max: item.quantity,
          ),
          DropdownSearch<dynamic>(
            mode: Mode.BOTTOM_SHEET,
            showSelectedItem: false,
            autoFocusSearchBox: true,
            selectedItem: null,
            errorBuilder: (context, entry, exception) {
              print("entry: $entry");
              print(exception.toString());

              return Text(
                exception.toString(),
                style: TextStyle(
                  fontSize: 10,
                )
              );
            },
            onFind: (String filter) async {

              Map<String, String> _filters = {
                "search": filter,
                "offset": "0",
                "limit": "25"
              };

              final List<InvenTreeModel> results = await InvenTreeStockLocation().list(filters: _filters);

              List<dynamic> items = [];

              for (InvenTreeModel loc in results) {
                if (loc is InvenTreeStockLocation) {
                  items.add(loc.jsondata);
                }
              }

              return items;
            },
            label: L10().stockLocation,
            hint: L10().searchLocation,
            onChanged: null,
            itemAsString: (dynamic location) {
              return location['pathstring'];
            },
            onSaved: (dynamic location) {
              if (location == null) {
                location_pk = null;
              } else {
                location_pk = location['pk'];
              }
            },
            isFilteredOnline: true,
            showSearchBox:  true,
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
            InvenTreePart().get(item.partId).then((var part) {
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
            title: Text(L10().serialNumber),
            leading: FaIcon(FontAwesomeIcons.hashtag),
            trailing: Text("${item.serialNumber}"),
          )
      );
    } else {
      tiles.add(
          ListTile(
            title: Text(L10().quantity),
            leading: FaIcon(FontAwesomeIcons.cubes),
            trailing: Text("${item.quantityString}"),
          )
      );
    }

    // Location information
    if ((item.locationId > 0) && (item.locationName.isNotEmpty)) {
      tiles.add(
          ListTile(
            title: Text(L10().stockLocation),
            subtitle: Text("${item.locationPathString}"),
            leading: FaIcon(
              FontAwesomeIcons.mapMarkerAlt,
              color: COLOR_CLICK,
            ),
            onTap: () {
              if (item.locationId > 0) {
                InvenTreeStockLocation().get(item.locationId).then((var loc) {

                  if (loc is InvenTreeStockLocation) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => LocationDisplayWidget(loc)));
                  }
                });
              }
            },
          )
      );
    } else {
      tiles.add(
          ListTile(
            title: Text(L10().stockLocation),
            leading: FaIcon(FontAwesomeIcons.mapMarkerAlt),
            subtitle: Text(L10().locationNotSet),
          )
      );
    }

    if (item.batch.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().batchCode),
          subtitle: Text(item.batch),
          leading: FaIcon(FontAwesomeIcons.layerGroup),
        )
      );
    }

    if (item.packaging.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().packaging),
          subtitle: Text(item.packaging),
          leading: FaIcon(FontAwesomeIcons.box),
        )
      );
    }

    // Last update?
    if (item.updatedDateString.isNotEmpty) {

      tiles.add(
        ListTile(
          title: Text(L10().lastUpdated),
          subtitle: Text(item.updatedDateString),
          leading: FaIcon(FontAwesomeIcons.calendarAlt)
        )
      );
    }

    // Stocktake?
    if (item.stocktakeDateString.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().lastStocktake),
          subtitle: Text(item.stocktakeDateString),
          leading: FaIcon(FontAwesomeIcons.calendarAlt)
        )
      );
    }

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
          leading: FaIcon(FontAwesomeIcons.link, color: COLOR_CLICK),
          onTap: () {
            item.openLink();
          },
        )
      );
    }

    if ((item.testResultCount > 0) || (part?.isTrackable ?? false)) {
      tiles.add(
          ListTile(
              title: Text(L10().testResults),
              leading: FaIcon(FontAwesomeIcons.tasks, color: COLOR_CLICK),
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

    if (item.hasPurchasePrice) {
      tiles.add(
        ListTile(
          title: Text(L10().purchasePrice),
          leading: FaIcon(FontAwesomeIcons.dollarSign),
          trailing: Text(item.purchasePrice),
        )
      );
    }

    // TODO - Is this stock item linked to a PurchaseOrder?

    // TODO - Re-enable stock item history display
    if (false && item.trackingItemCount > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().history),
          leading: FaIcon(FontAwesomeIcons.history),
          trailing: Text("${item.trackingItemCount}"),
          onTap: () {
            // TODO: Load tracking history

            // TODO: Push tracking history page to the route

          },
        )
      );
    }

    // Notes field
    tiles.add(
      ListTile(
        title: Text(L10().notes),
        leading: FaIcon(FontAwesomeIcons.stickyNote, color: COLOR_CLICK),
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

    return tiles;
  }

  List<Widget> actionTiles(BuildContext context) {
    List<Widget> tiles = [];

    tiles.add(headerTile());

    // First check that the user has the required permissions to adjust stock
    if (!InvenTreeAPI().checkPermission('stock', 'change')) {
      tiles.add(
        ListTile(
          title: Text(L10().permissionRequired),
          leading: FaIcon(FontAwesomeIcons.userTimes)
        )
      );

      tiles.add(
        ListTile(
          subtitle: Text(L10().permissionAccountDenied),
        )
      );

      return tiles;
    }

    if (!item.isSerialized()) {
      tiles.add(
          ListTile(
              title: Text(L10().countStock),
              leading: FaIcon(FontAwesomeIcons.checkCircle, color: COLOR_CLICK),
              onTap: _countStockDialog,
              trailing: Text(item.quantityString),
          )
      );

      tiles.add(
          ListTile(
              title: Text(L10().removeStock),
              leading: FaIcon(FontAwesomeIcons.minusCircle, color: COLOR_CLICK),
              onTap: _removeStockDialog,
          )
      );

      tiles.add(
          ListTile(
              title: Text(L10().addStock),
              leading: FaIcon(FontAwesomeIcons.plusCircle, color: COLOR_CLICK),
              onTap: _addStockDialog,
          )
      );
    }

    tiles.add(
      ListTile(
        title: Text(L10().transferStock),
        leading: FaIcon(FontAwesomeIcons.exchangeAlt, color: COLOR_CLICK),
        onTap: () { _transferStockDialog(context); },
      )
    );

    // Scan item into a location
    tiles.add(
      ListTile(
        title: Text(L10().scanIntoLocation),
        leading: FaIcon(FontAwesomeIcons.exchangeAlt, color: COLOR_CLICK),
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
          title: Text(L10().barcodeAssign),
          leading: FaIcon(FontAwesomeIcons.barcode, color: COLOR_CLICK),
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
          title: Text(L10().barcodeUnassign),
          leading: FaIcon(FontAwesomeIcons.barcode, color: COLOR_CLICK),
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
          title: Text(L10().details),
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          title: Text(L10().actions),
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
            tiles: actionTiles(context)
          ).toList()
        );
      default:
        return ListView();
    }
  }

  @override
  Widget getBody(BuildContext context) {
    return getSelectedWidget(tabIndex);
  }
}