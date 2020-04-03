
import 'package:InvenTree/inventree/stock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LocationDisplayWidget extends StatefulWidget {

  LocationDisplayWidget(this.location, {Key key}) : super(key: key);

  final InvenTreeStockLocation location;

  final String title = "Location";

  @override
  _LocationDisplayState createState() => _LocationDisplayState(location);
}


class _LocationDisplayState extends State<LocationDisplayWidget> {

  _LocationDisplayState(this.location) {
    _requestData();
  }

  final InvenTreeStockLocation location;

  List<InvenTreeStockLocation> _sublocations = List<InvenTreeStockLocation>();

  List<InvenTreeStockItem> _items = List<InvenTreeStockItem>();

  String get _title {
    // TODO
    return "Location:";
  }

  void _requestData() {

    int pk = location?.pk ?? -1;

    // Request a list of sub-locations under this one
    InvenTreeStockLocation().list(filters: {"parent": "$pk"}).then((var locs) {
      _sublocations.clear();

      for (var loc in locs) {
        if (loc is InvenTreeStockLocation) {
          _sublocations.add(loc);
        }
      }

      setState(() {});

    // Request a list of stock-items under this one
    InvenTreeStockItem().list(filters: {"location": "$pk"}).then((var items) {
      _items.clear();

      for (var item in items) {
        if (item is InvenTreeStockItem) {
          _items.add(item);
        }
      }

      setState(() {});
    });

    });

    // TODO
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Sublocations - ${_sublocations.length}",
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Divider(),
            Text(
              "Stock Items - ${_items.length}",
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.bold),
            )
          ],
        )
      ),
    );
  }
}