

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/drawer.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class StockDetailWidget extends StatefulWidget {

  StockDetailWidget(this.item, {Key key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState(item);
}


class _StockItemDisplayState extends State<StockDetailWidget> {

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

  /**
   * Function to reload the page data
   */
  Future<void> _refresh() async {

    await item.reload();
    setState(() {});
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
    _refresh();
  }

  void _addStockDialog() async {
    showDialog(context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Add Stock"),
          actions: <Widget>[
            FlatButton(
              child: Text("Add"),
              onPressed: () {
                if (_addStockKey.currentState.validate()) _addStock();
              },
            )
          ],
          content: Form(
            key: _addStockKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text("Current Quantity: ${item.quantity}"),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Add stock",
                  ),
                  keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
                  controller: _quantityController,
                  validator: (value) {
                    if (value.isEmpty) return "Value cannot be empty";

                    double quantity = double.tryParse(value);
                    if (quantity == null) return "Value cannot be converted to a number";
                    if (quantity <= 0) return "Value must be positive";

                    return null;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Notes",
                  ),
                  controller: _notesController,
                )
              ],
            )
          ),
        );
      }
    );
    // TODO - Form for adding stock
  }

  void _removeStock() async {
    Navigator.of(context).pop();

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    var response = await item.removeStock(quantity, notes: _notesController.text);
    _notesController.clear();

    // TODO - Handle error cases

    _refresh();
  }

  void _removeStockDialog() {
    showDialog(context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Remove Stock"),
          actions: <Widget>[
            FlatButton(
              child: Text("Remove"),
              onPressed: () {
                if (_removeStockKey.currentState.validate()) _removeStock();
              },
            )
          ],
          content: Form(
            key: _removeStockKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("Current quantity: ${item.quantity}"),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Remove stock",
                  ),
                  controller: _quantityController,
                  keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
                  validator: (value) {
                    if (value.isEmpty) return "Value cannot be empty";

                    double quantity = double.tryParse(value);

                    if (quantity == null) return "Value cannot be converted to a number";
                    if (quantity <= 0) return "Value must be positive";

                    if (quantity > item.quantity) return "Cannot take more than current quantity";

                    return null;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Notes",
                  ),
                  controller: _notesController,
                ),
              ],
            )
          ),
        );
      }
    );
  }

  void _countStock() async {

    Navigator.of(context).pop();

    double quantity = double.parse(_quantityController.text);
    _quantityController.clear();

    var response = await item.countStock(quantity, notes: _notesController.text);
    _notesController.clear();

    // TODO - Handle error cases

    _refresh();
  }

  void _countStockDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Count Stock"),
          actions: <Widget>[
            FlatButton(
              child: Text("Count"),
              onPressed: () {
                if (_countStockKey.currentState.validate()) _countStock();
              },
            )
          ],
          content: Form(
            key: _countStockKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Count stock",
                    hintText: "${item.quantity}",
                  ),
                  controller: _quantityController,
                  keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
                  validator: (value) {
                    if (value.isEmpty) return "Value cannot be empty";

                    double quantity = double.tryParse(value);
                    if (quantity == null) return "Value cannot be converted to a number";
                    if (quantity < 0) return "Value cannot be negative";

                    return null;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Notes",
                  ),
                  controller: _notesController,
                )
              ],
            )
          )
        );
      }
    );
  }


  void _transferStock(int location) {
    // TODO
  }

  void _transferStockDialog() {
    // TODO - Form for transferring stock
  }

  /*
   * Construct a list of detail elements about this StockItem.
   * The number of elements may vary depending on the StockItem details
   */
  List<Widget> stockTiles() {
    List<Widget> tiles = [];

    // Image / name / description
    tiles.add(
      Card(
        child: ListTile(
          title: Text("${item.partName}"),
          subtitle: Text("${item.partDescription}"),
          leading: Image(
            image: InvenTreeAPI().getImage(item.partImage),
          ),
          trailing: IconButton(
            icon: FaIcon(FontAwesomeIcons.edit),
            onPressed: _editStockItemDialog,
          )
        )
      )
    );

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


    // Location information
    if (item.locationName.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text("Stock Location"),
          subtitle: Text("${item.locationName}"),
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
    }

    // Supplier part?
    if (item.supplierPartId > 0) {
      tiles.add(
        ListTile(
          title: Text("${item.supplierName}"),
          subtitle: Text("${item.supplierSKU}"),
          leading: FaIcon(FontAwesomeIcons.industry),
          trailing: Image(
            image: InvenTreeAPI().getImage(item.supplierImage),
            height: 32,
          ),
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

  /*
   * Return a list of context-sensitive action buttons.
   * Not all buttons will be avaialable for a given StockItem,
   * depending on the properties of that StockItem
   */
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Stock Item"),
      ),
      drawer: new InvenTreeDrawer(context),
      floatingActionButton: SpeedDial(
        visible: true,
        animatedIcon: AnimatedIcons.menu_close,
        heroTag: 'stock-item-fab',
        children: actionButtons(),
      ),
      body: Center(
        child: new RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            children: stockTiles(),
          )
        )
      )
    );
  }
}