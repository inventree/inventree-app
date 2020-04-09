

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

  final _addStockKey = GlobalKey<FormState>();

  _StockItemDisplayState(this.item) {
    // TODO
  }

  final InvenTreeStockItem item;

  void _editStockItem() {
    // TODO - Form for editing stock item
  }

  void _addStock() {
    showDialog(context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Add Stock"),
          actions: <Widget>[
            FlatButton(
              child: Text("Add"),
              onPressed: () {
                _addStockKey.currentState.validate();
              },
            )
          ],
          content: Form(
            key: _addStockKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  decoration: InputDecoration(labelText: "Stock Quantity"),
                  keyboardType: TextInputType.numberWithOptions(signed:false, decimal:true),
                  validator: (value) {
                    if (value.isEmpty) {
                      return "Value cannot be empty";
                    }

                    double quantity = double.tryParse(value);

                    if (quantity == null) {
                      return "Value cannot be converted to a number";
                    }

                    if (quantity <= 0) {
                      return "Value must be positive";
                    }

                    print("Adding stock!");

                    item.addStock(quantity).then((var response) {
                      print("added stock");
                    });
                  },
                ),
              ],
            )
          ),
        );
      }
    );
    // TODO - Form for adding stock
  }

  void _removeStock() {
    // TODO - Form for removing stock
  }

  void _countStock() {
    // TODO - Form for counting stock
  }

  void _transferStock() {
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
            onPressed: _editStockItem,
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
            InvenTreePart().get(item.partId).then((var part) {
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
              InvenTreeStockLocation().get(item.locationId).then((var loc) {
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
        onTap: _addStock,
      )
      );

      buttons.add(SpeedDialChild(
        child: Icon(FontAwesomeIcons.minusCircle),
        label: "Remove Stock",
        onTap: _removeStock,
      ),
      );

      buttons.add(SpeedDialChild(
        child: Icon(FontAwesomeIcons.checkCircle),
        label: "Count Stock",
        onTap: _countStock,
      ));
    }

    buttons.add(SpeedDialChild(
      child: Icon(FontAwesomeIcons.exchangeAlt),
      label: "Transfer Stock",
      onTap: _transferStock,
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
        child: ListView(
          children: stockTiles(),
        )
      )
    );
  }
}