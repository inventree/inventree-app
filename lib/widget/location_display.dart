
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:InvenTree/widget/stock_display.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

  String _locationFilter = '';

  List<InvenTreeStockLocation> get sublocations {
    
    if (_locationFilter.isEmpty || _sublocations.isEmpty) {
      return _sublocations;
    } else {
      return _sublocations.where((loc) => loc.filter(_locationFilter)).toList();
    }
  }

  List<InvenTreeStockItem> _items = List<InvenTreeStockItem>();

  String get _title {

    if (location == null) {
      return "Location:";
    } else {
      return "Stock Location '${location.name}'";
    }
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      drawer: new InvenTreeDrawer(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Sublocations - ${_sublocations.length}",
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              decoration: InputDecoration(
                hintText: "Filter locations",
              ),
              onChanged: (text) {
                setState(() {
                  _locationFilter = text.trim().toLowerCase();
                });
              },
            ),
            Expanded(child: SublocationList(sublocations)),
            Divider(),
            Text(
              "Stock Items - ${_items.length}",
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(child: StockList(_items)),
          ],
        )
      ),
    );
  }
}


class SublocationList extends StatelessWidget {
  final List<InvenTreeStockLocation> _locations;

  SublocationList(this._locations);

  void _openLocation(BuildContext context, int pk) {

    InvenTreeStockLocation().get(pk).then((var loc) {
      if (loc is InvenTreeStockLocation) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
      }
    });
  }

  Widget _build(BuildContext context, int index) {
    InvenTreeStockLocation loc = _locations[index];

    return ListTile(
      title: Text('${loc.name}'),
      subtitle: Text("${loc.description}"),
      onTap: () {
        _openLocation(context, loc.pk);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemBuilder: _build, itemCount: _locations.length);
  }
}

class StockList extends StatelessWidget {
  final List<InvenTreeStockItem> _items;

  StockList(this._items);

  void _openItem(BuildContext context, int pk) {
    InvenTreeStockItem().get(pk).then((var item) {
      if (item is InvenTreeStockItem) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockItemDisplayWidget(item)));
      }
    });
  }

  Widget _build(BuildContext context, int index) {
    InvenTreeStockItem item = _items[index];

    return ListTile(
      title: Text("${item.quantity.toString()} x ${item.partName}"),
      subtitle: Text("${item.description}"),
      onTap: () {
        _openItem(context, item.pk);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemBuilder: _build, itemCount: _items.length);
  }
}