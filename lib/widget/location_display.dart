import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/preferences.dart';

import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:InvenTree/widget/stock_detail.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LocationDisplayWidget extends StatefulWidget {

  LocationDisplayWidget(this.location, {Key key}) : super(key: key);

  final InvenTreeStockLocation location;

  final String title = "Location";

  @override
  _LocationDisplayState createState() => _LocationDisplayState(location);
}

class _LocationDisplayState extends RefreshableState<LocationDisplayWidget> {

  final InvenTreeStockLocation location;

  final _editLocationKey = GlobalKey<FormState>();

  @override
  String getAppBarTitle(BuildContext context) { return "Stock Location"; }

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    return <Widget>[
      IconButton(
        icon: FaIcon(FontAwesomeIcons.edit),
        tooltip: I18N.of(context).edit,
        onPressed: _editLocationDialog,
      )
    ];
  }

  void _editLocation(Map<String, String> values) async {

    final bool result = await location.update(context, values: values);

    showSnackIcon(
      refreshableKey,
      result ? "Location edited" : "Location editing failed",
      success: result
    );

    refresh();
  }

  void _editLocationDialog() {
    // Values which an be edited
    var _name;
    var _description;

    showFormDialog(context, I18N.of(context).editLocation,
      key: _editLocationKey,
      callback: () {
        _editLocation({
          "name": _name,
          "description": _description
        });
      },
      fields: <Widget> [
        StringField(
          label: I18N.of(context).name,
          initial: location.name,
          onSaved: (value) => _name = value,
        ),
        StringField(
          label: I18N.of(context).description,
          initial: location.description,
          onSaved: (value) => _description = value,
        )
      ]
    );
  }

  _LocationDisplayState(this.location) {}

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

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh();
  }

  @override
  Future<void> request(BuildContext context) async {

    int pk = location?.pk ?? -1;

    // Reload location information
    await location.reload(context);

    // Request a list of sub-locations under this one
    await InvenTreeStockLocation().list(context, filters: {"parent": "$pk"}).then((var locs) {
      _sublocations.clear();

      for (var loc in locs) {
        if (loc is InvenTreeStockLocation) {
          _sublocations.add(loc);
        }
      }
    });

    setState(() {});

    await InvenTreeStockItem().list(context, filters: {"location": "$pk"}).then((var items) {
      _items.clear();

      for (var item in items) {
        if (item is InvenTreeStockItem) {
          _items.add(item);
        }
      }
    });

    setState(() {});
  }

  Widget locationDescriptionCard() {
    if (location == null) {
      return Card(
        child: ListTile(
          title: Text(I18N.of(context).stockLocations),
          subtitle: Text(I18N.of(context).stockTopLevel),
          leading: FaIcon(FontAwesomeIcons.levelUpAlt),
        )
      );
    } else {
      return Card(
        child: Column(
          children: <Widget> [
            ListTile(
              title: Text("${location.name}"),
              subtitle: Text("${location.description}"),
            ),
            ListTile(
              title: Text("Parent Category"),
              subtitle: Text("${location.parentpathstring}"),
              leading: FaIcon(FontAwesomeIcons.levelUpAlt),
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
  Widget getBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: onTabSelectionChanged,
        items: <BottomNavigationBarItem> [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.boxes),
            title: Text(I18N.of(context).stock),
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.wrench),
            title: Text(I18N.of(context).actions),
          )
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


List<Widget> detailTiles() {
    List<Widget> tiles = [];

    // Location description
    tiles.add(locationDescriptionCard());

    // Sublocation panel
    ExpansionPanel sublocations = ExpansionPanel(
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
    );

    ExpansionPanel subitems = ExpansionPanel(
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
    );

    // Sublocations and items
    tiles.add(
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
            sublocations,
            subitems,
          ]
      )
    );

    return tiles;
  }

  List<Widget> actionTiles() {
    List<Widget> tiles = [];

    tiles.add(locationDescriptionCard());

    // Scan items into location
    tiles.add(
      ListTile(
        title: Text("Scan in Stock Item"),
        leading: FaIcon(FontAwesomeIcons.exchangeAlt),
        trailing: FaIcon(FontAwesomeIcons.qrcode),
        onTap: null,
      )
    );

    // Move location into another location
    tiles.add(
      ListTile(
        title: Text("Move Stock Location"),
        leading: FaIcon(FontAwesomeIcons.sitemap),
        trailing: FaIcon(FontAwesomeIcons.qrcode),
      )
    );

    return tiles;
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
    return ListView.separated(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemBuilder: _build,
        separatorBuilder: (_, __) => const Divider(height: 3),
        itemCount: _locations.length
    );
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
      leading: InvenTreeAPI().getImage(
        item.partThumbnail,
        width: 40,
        height: 40,
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
    return ListView.separated(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        separatorBuilder: (_, __) => const Divider(height: 3),
        itemBuilder: _build, itemCount: _items.length);
  }
}