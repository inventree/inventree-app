

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/drawer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class StockDetailWidget extends StatefulWidget {

  StockDetailWidget(this.item, {Key key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState(item);
}


class _StockItemDisplayState extends State<StockDetailWidget> {

  _StockItemDisplayState(this.item) {
    // TODO
  }

  final InvenTreeStockItem item;

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
            onPressed: null,
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
    tiles.add(
      ListTile(
        title: Text("Quantity"),
        leading: FaIcon(FontAwesomeIcons.cubes),
        trailing: Text("${item.quantity}"),
      )
    );

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

    buttons.add(SpeedDialChild(
      child: Icon(Icons.add_circle),
      label: "Add Stock",
      onTap: null,
      )
    );

    buttons.add(SpeedDialChild(
      child: Icon(Icons.remove_circle),
      label: "Remove Stock",
      onTap: null,
      ),
    );

    buttons.add(SpeedDialChild(
      child: Icon(Icons.check_circle),
      label: "Count Stock",
      onTap: null,
    ));

    buttons.add(SpeedDialChild(
      child: Icon(Icons.location_on),
      label: "Transfer Stock",
      onTap: null,
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