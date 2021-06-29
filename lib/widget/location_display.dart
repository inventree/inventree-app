import 'package:InvenTree/api.dart';
import 'package:InvenTree/app_settings.dart';
import 'package:InvenTree/barcode.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/widget/progress.dart';

import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:InvenTree/widget/stock_detail.dart';
import 'package:InvenTree/widget/paginator.dart';
import 'package:InvenTree/l10.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

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

    List<Widget> actions = [];

    /*
    actions.add(
      IconButton(
        icon: FaIcon(FontAwesomeIcons.search),
        onPressed: () {

          Map<String, String> filters = {};

          if (location != null) {
            filters["location"] = "${location.pk}";
          }

          showSearch(
            context: context,
            delegate: StockSearchDelegate(context, filters: filters)
          );
        }
      ),
    );
     */

    if ((location != null) && (InvenTreeAPI().checkPermission('stock_location', 'change'))) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.edit),
          tooltip: L10().edit,
          onPressed: _editLocationDialog,
        )
      );
    }

    return actions;
  }

  void _editLocation(Map<String, String> values) async {

    final bool result = await location.update(context, values: values);

    showSnackIcon(
      result ? "Location edited" : "Location editing failed",
      success: result
    );

    refresh();
  }

  void _editLocationDialog() {
    // Values which an be edited
    var _name;
    var _description;

    showFormDialog(L10().editLocation,
      key: _editLocationKey,
      callback: () {
        _editLocation({
          "name": _name,
          "description": _description
        });
      },
      fields: <Widget> [
        StringField(
          label: L10().name,
          initial: location.name,
          onSaved: (value) => _name = value,
        ),
        StringField(
          label: L10().description,
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

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh();
  }

  @override
  Future<void> request(BuildContext context) async {

    int pk = location?.pk ?? -1;

    // Reload location information
    if (location != null) {
      await location.reload(context);
    }

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
  }

  Widget locationDescriptionCard({bool includeActions = true}) {
    if (location == null) {
      return Card(
        child: ListTile(
          title: Text(L10().stockTopLevel),
        )
      );
    } else {

      List<Widget> children = [
        ListTile(
          title: Text("${location.name}"),
          subtitle: Text("${location.description}"),
        ),
      ];

      if (includeActions) {
        children.add(
            ListTile(
              title: Text(L10().parentCategory),
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
        );
      }

      return Card(
        child: Column(
          children: children,
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
            icon: FaIcon(FontAwesomeIcons.sitemap),
            label: L10().details,
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.boxes),
            label: L10().stock,
          ),
          // TODO - Add in actions when they are written...
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.wrench),
            label: L10().actions,
          )
        ]
    );
  }

  int stockItemCount = 0;

  Widget getSelectedWidget(int index) {

    // Construct filters for paginated stock list
    Map<String, String> filters = {};

    if (location != null) {
      filters["location"] = "${location.pk}";
    }

    switch (index) {
      case 0:
        return ListView(
          children: detailTiles(),
        );
      case 1:
        return PaginatedStockList(filters);
      case 2:
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
    List<Widget> tiles = [
      locationDescriptionCard(),
      ListTile(
        title: Text(
          L10().sublocations,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: sublocations.length > 0 ? Text("${sublocations.length}") : null,
      ),
    ];

    if (loading) {
      tiles.add(progressIndicator());
    } else if (_sublocations.length > 0) {
      tiles.add(SublocationList(_sublocations));
    } else {
      tiles.add(ListTile(
        title: Text(L10().sublocationNone),
        subtitle: Text(L10().sublocationNoneDetail)
      ));
    }

    return tiles;
  }


  List<Widget> actionTiles() {
    List<Widget> tiles = [];

    tiles.add(locationDescriptionCard(includeActions: false));
    
    if (location != null) {
      // Stock adjustment actions
      if (InvenTreeAPI().checkPermission('stock', 'change')) {
        // Scan items into location
        tiles.add(
            ListTile(
              title: Text(L10().barcodeScanInItems),
              leading: FaIcon(FontAwesomeIcons.exchangeAlt),
              trailing: FaIcon(FontAwesomeIcons.qrcode),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                        InvenTreeQRView(
                            StockLocationScanInItemsHandler(location)))
                ).then((context) {
                  refresh();
                });
              },
            )
        );
      }
    }

    // Move location into another location
    // TODO: Implement this!
    /*
    tiles.add(
      ListTile(
        title: Text("Move Stock Location"),
        leading: FaIcon(FontAwesomeIcons.sitemap),
        trailing: FaIcon(FontAwesomeIcons.qrcode),
      )
    );
     */

    if (tiles.length <= 1) {
      tiles.add(
        ListTile(
          title: Text(
              L10().actionsNone,
            style: TextStyle(
              fontStyle: FontStyle.italic
            ),
          )
        )
      );
    }

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

/**
 * Widget for displaying a list of stock items within a stock location.
 *
 * Users server-side pagination for snappy results
 */

class PaginatedStockList extends StatefulWidget {

  final Map<String, String> filters;

  PaginatedStockList(this.filters);

  @override
  _PaginatedStockListState createState() => _PaginatedStockListState(filters);
}


class _PaginatedStockListState extends State<PaginatedStockList> {

  static const _pageSize = 25;

  String _searchTerm = "";

  final Map<String, String> filters;

  _PaginatedStockListState(this.filters);

  final PagingController<int, InvenTreeStockItem> _pagingController = PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });

    super.initState();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  int resultCount = 0;

  Future<void> _fetchPage(int pageKey) async {
    try {

      Map<String, String> params = this.filters;

      params["search"] = "${_searchTerm}";

      // Do we include stock items from sub-locations?
      final bool cascade = await InvenTreeSettingsManager().getValue("stockSublocation", false);
      params["cascade"] = "${cascade}";

      final page = await InvenTreeStockItem().listPaginated(_pageSize, pageKey, filters: params);
      final isLastPage = page.length < _pageSize;

      // Construct a list of stock item objects
      List<InvenTreeStockItem> items = [];

      for (var result in page.results) {
        if (result is InvenTreeStockItem) {
          items.add(result);
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        final int nextPageKey = pageKey + page.length;
        _pagingController.appendPage(items, nextPageKey);
      }

      setState(() {
        resultCount = page.count;
      });

    } catch (error) {
      _pagingController.error = error;
    }
  }

  void _openItem(BuildContext context, int pk) {
    InvenTreeStockItem().get(context, pk).then((var item) {
      if (item is InvenTreeStockItem) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
      }
    });
  }

  Widget _buildItem(BuildContext context, InvenTreeStockItem item) {
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

  final TextEditingController searchController = TextEditingController();

  void updateSearchTerm() {
    _searchTerm = searchController.text;
    _pagingController.refresh();
  }

  @override
  Widget build (BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        PaginatedSearchWidget(searchController, updateSearchTerm, resultCount),
        Expanded(
          child: CustomScrollView(
            shrinkWrap: true,
            physics: ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            slivers: <Widget>[
              // TODO - Search input
              PagedSliverList.separated(
                  pagingController: _pagingController,
                  builderDelegate: PagedChildBuilderDelegate<InvenTreeStockItem>(
                    itemBuilder: (context, item, index) {
                      return _buildItem(context, item);
                    },
                    noItemsFoundIndicatorBuilder: (context) {
                      return NoResultsWidget("No stock items found");
                    }
                  ),
                  separatorBuilder: (context, item) => const Divider(height: 1),
              )
            ]
          )
        )
      ]
    );
  }
}
