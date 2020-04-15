import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/preferences.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:InvenTree/widget/stock_detail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LocationDisplayWidget extends StatefulWidget {



  LocationDisplayWidget(this.location, {Key key}) : super(key: key);

  final InvenTreeStockLocation location;

  final String title = "Location";

  @override
  _LocationDisplayState createState() => _LocationDisplayState(location);
}


class _LocationDisplayState extends State<LocationDisplayWidget> {

  BuildContext context;

  _LocationDisplayState(this.location) {
  }

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestData(context));
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
      return "Stock Locations";
    } else {
      return "Stock Location - ${location.name}";
    }
  }

  Future<void> _refresh() async {
    await _requestData(context);
  }

  /*
   * Request data from the server.
   * It will be displayed once loaded
   *
   * - List of sublocations under this one
   * - List of stock items at this location
   */
  Future<void> _requestData(BuildContext context) async {

    int pk = location?.pk ?? -1;

    // Request a list of sub-locations under this one
    InvenTreeStockLocation().list(context, filters: {"parent": "$pk"}).then((var locs) {
      _sublocations.clear();

      for (var loc in locs) {
        if (loc is InvenTreeStockLocation) {
          _sublocations.add(loc);
        }
      }

      setState(() {});

      // Request a list of stock-items under this one
      InvenTreeStockItem().list(context, filters: {"location": "$pk"}).then((var items) {
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

  Widget locationDescriptionCard() {
    if (location == null) {
      return Card(
        child: ListTile(
          title: Text("Stock Locations"),
          subtitle: Text("Top level stock location")
        )
      );
    } else {
      return Card(
        child: Column(
          children: <Widget> [
            ListTile(
              title: Text("${location.name}"),
              subtitle: Text("${location.description}"),
              trailing: IconButton(
                icon: FaIcon(FontAwesomeIcons.edit),
                onPressed: null,
              ),
            ),
            ListTile(
              title: Text("Parent Category"),
              subtitle: Text("${location.parentpathstring}"),
              onTap: () {
                if (location.parentId < 0) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
                } else {
                  InvenTreeStockLocation().get(context, location.parentId).then((var loc) {
                    if (loc is InvenTreeStockLocation) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
                    }
                  });
                }
              },
            )
          ]
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    // Save the context
    this.context = context;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      drawer: new InvenTreeDrawer(context),
      body: new RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: <Widget> [
            locationDescriptionCard(),
            ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  switch (index) {
                    case 0:
                      InvenTreePreferences().expandLocationList = !isExpanded;
                      break;
                    case 1:
                      InvenTreePreferences().expandStockList = !isExpanded;
                      break;
                    default:
                      break;
                  }
                });

              },
              children: <ExpansionPanel> [
                ExpansionPanel(
                  headerBuilder: (BuildContext context, bool isExpanded) {
                    return ListTile(
                      title: Text("Sublocations"),
                      leading: FaIcon(FontAwesomeIcons.mapMarkerAlt),
                      trailing: Text("${_sublocations.length}"),
                      onTap: () {
                        setState(() {
                          InvenTreePreferences().expandLocationList = !InvenTreePreferences().expandLocationList;
                        });
                      },
                    );
                  },
                  body: SublocationList(_sublocations),
                  isExpanded: InvenTreePreferences().expandLocationList && _sublocations.length > 0,
                ),
                ExpansionPanel(
                  headerBuilder: (BuildContext context, bool isExpanded) {
                    return ListTile(
                      title: Text("Stock Items"),
                      leading: FaIcon(FontAwesomeIcons.boxes),
                      trailing: Text("${_items.length}"),
                      onTap: () {
                        setState(() {
                          InvenTreePreferences().expandStockList = !InvenTreePreferences().expandStockList;
                        });
                      },
                    );
                  },
                  body: StockList(_items),
                  isExpanded: InvenTreePreferences().expandStockList && _items.length > 0,
                )
              ]
            ),
          ]
        )
      )
    );
  }
}


class SublocationList extends StatelessWidget {
  final List<InvenTreeStockLocation> _locations;

  SublocationList(this._locations);

  void _openLocation(BuildContext context, int pk) {

    InvenTreeStockLocation().get(context, pk).then((var loc) {
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
      trailing: Text("${loc.itemcount}"),
      onTap: () {
        _openLocation(context, loc.pk);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemBuilder: _build, itemCount: _locations.length);
  }
}

class StockList extends StatelessWidget {
  final List<InvenTreeStockItem> _items;

  StockList(this._items);

  void _openItem(BuildContext context, int pk) {
    InvenTreeStockItem().get(context, pk).then((var item) {
      if (item is InvenTreeStockItem) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
      }
    });
  }

  Widget _build(BuildContext context, int index) {
    InvenTreeStockItem item = _items[index];

    return ListTile(
      title: Text("${item.partName}"),
      subtitle: Text("${item.partDescription}"),
      leading: Image(
        image: InvenTreeAPI().getImage(item.partThumbnail),
        width: 48,
      ),
      trailing: Text("${item.displayQuantity}",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: () {
        _openItem(context, item.pk);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemBuilder: _build, itemCount: _items.length);
  }
}