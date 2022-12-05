import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/location_list.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock_detail.dart";
import "package:inventree/widget/stock_list.dart";


/*
 * Widget for displaying detail view for a single StockLocation instance
 */
class LocationDisplayWidget extends StatefulWidget {

  LocationDisplayWidget(this.location, {Key? key}) : super(key: key);

  final InvenTreeStockLocation? location;

  final String title = L10().stockLocation;

  @override
  _LocationDisplayState createState() => _LocationDisplayState(location);
}

class _LocationDisplayState extends RefreshableState<LocationDisplayWidget> {

  _LocationDisplayState(this.location);

  final InvenTreeStockLocation? location;

  bool showFilterOptions = false;

  @override
  String getAppBarTitle(BuildContext context) { return L10().stockLocation; }

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (location != null) {

      // Add "locate" button
      if (InvenTreeAPI().supportsMixin("locate")) {
        actions.add(
          IconButton(
            icon: FaIcon(FontAwesomeIcons.searchLocation),
            tooltip: L10().locateLocation,
            onPressed: () async {
              _locateStockLocation(context);
            },
          )
        );
      }

      // Add "edit" button
      if (InvenTreeAPI().checkPermission("stock_location", "change")) {
        actions.add(
            IconButton(
              icon: FaIcon(FontAwesomeIcons.edit),
              tooltip: L10().edit,
              onPressed: () { _editLocationDialog(context); },
            )
        );
      }
    }

    return actions;
  }

  /*
   * Request identification of this location
   */
  Future<void> _locateStockLocation(BuildContext context) async {

    final _loc = location;

    if (_loc != null) {
      InvenTreeAPI().locateItemOrLocation(context, location: _loc.pk);
    }
  }

  /*
   * Launch a dialog form to edit this stock location
   */
  void _editLocationDialog(BuildContext context) {

    final _loc = location;

    if (_loc == null) {
      return;
    }

    _loc.editForm(
      context,
      L10().editLocation,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().locationUpdated, success: true);
      }
    );
  }

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh(context);
  }

  @override
  Future<void> request(BuildContext context) async {

    // Reload location information
    if (location != null) {
      final bool result = await location!.reload();

      if (!result) {
        Navigator.of(context).pop();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _newLocation(BuildContext context) async {

    int pk = location?.pk ?? -1;

    InvenTreeStockLocation().createForm(
      context,
      L10().locationCreate,
      data: {
        "parent": (pk > 0) ? pk : null,
      },
      onSuccess: (result) async {

        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var loc = InvenTreeStockLocation.fromJson(data);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocationDisplayWidget(loc)
            )
          );
        }
      }
    );
  }

  Future<void> _newStockItem(BuildContext context) async {

    int pk = location?.pk ?? -1;

    if (location != null && pk <= 0) {
      return;
    }

    InvenTreeStockItem().createForm(
      context,
      L10().stockItemCreate,
      data: {
        "location": location != null ? pk : null,
      },
      onSuccess: (result) async {

        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var item = InvenTreeStockItem.fromJson(data);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockDetailWidget(item)
            )
          );
        }
      }
    );

  }

  Widget locationDescriptionCard({bool includeActions = true}) {
    if (location == null) {
      return Card(
        child: ListTile(
          title: Text(
            L10().stockTopLevel,
            style: TextStyle(fontStyle: FontStyle.italic)
          ),
          leading: FaIcon(FontAwesomeIcons.boxes),
        )
      );
    } else {

      List<Widget> children = [
        ListTile(
          title: Text("${location!.name}"),
          subtitle: Text("${location!.description}"),
          leading: FaIcon(FontAwesomeIcons.boxes),
        ),
      ];

      if (includeActions) {
        children.add(
            ListTile(
              title: Text(L10().parentLocation),
              subtitle: Text("${location!.parentPathString}"),
              leading: FaIcon(FontAwesomeIcons.levelUpAlt, color: COLOR_CLICK),
              onTap: () async {

                int parentId = location?.parentId ?? -1;

                if (parentId < 0) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
                } else {

                  showLoadingOverlay(context);
                  var loc = await InvenTreeStockLocation().get(parentId);
                  hideLoadingOverlay();

                  if (loc is InvenTreeStockLocation) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(loc)));
                  }
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
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.wrench),
            label: L10().actions,
          )
        ]
    );
  }

  int stockItemCount = 0;

  Widget getSelectedWidget(int index) {

    switch (index) {
      case 0:
        return Column(
          children: detailTiles(),
        );
      case 1:
        return Column(
          children: stockTiles(),
        );
      case 2:
        return ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: actionTiles()
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

  // Construct the "details" panel
  List<Widget> detailTiles() {
    List<Widget> tiles = [
      locationDescriptionCard(),
      ListTile(
        title: Text(
          L10().sublocations,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: GestureDetector(
          child: FaIcon(FontAwesomeIcons.filter),
          onTap: () async {
            setState(() {
              showFilterOptions = !showFilterOptions;
            });
          },
        )
      ),
      Expanded(
        child: PaginatedStockLocationList(
          {
            "parent": location?.pk.toString() ?? "null",
          },
          showFilterOptions,
        ),
        flex: 10,
      )
    ];

    return tiles;
  }

  // Construct the "stock" panel
  List<Widget> stockTiles() {

    Map<String, String> filters = {
      "location": location?.pk.toString() ?? "null",
    };

    return [
      locationDescriptionCard(includeActions: false),
      ListTile(
        title: Text(
          L10().stock,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: GestureDetector(
          child: FaIcon(FontAwesomeIcons.filter),
          onTap: () async {
            setState(() {
              showFilterOptions = !showFilterOptions;
            });
          },
        ),
      ),
      Expanded(
        child: PaginatedStockItemList(
          filters,
          showFilterOptions,
        ),
        flex: 10,
      )
    ];
  }

  List<Widget> actionTiles() {
    List<Widget> tiles = [];

    tiles.add(locationDescriptionCard(includeActions: false));

    if (InvenTreeAPI().checkPermission("stock", "add")) {

      tiles.add(
        ListTile(
          title: Text(L10().locationCreate),
          subtitle: Text(L10().locationCreateDetail),
          leading: FaIcon(FontAwesomeIcons.sitemap, color: COLOR_CLICK),
          trailing: FaIcon(FontAwesomeIcons.plusCircle, color: COLOR_CLICK),
          onTap: () async {
            _newLocation(context);
          },
        )
      );

      tiles.add(
        ListTile(
          title: Text(L10().stockItemCreate),
          subtitle: Text(L10().stockItemCreateDetail),
          leading: FaIcon(FontAwesomeIcons.boxes, color: COLOR_CLICK),
          trailing: FaIcon(FontAwesomeIcons.plusCircle, color: COLOR_CLICK),
          onTap: () async {
            _newStockItem(context);
          },
        )
      );

    }

    if (location != null) {

      // Scan stock item into location
      if (InvenTreeAPI().checkPermission("stock", "change")) {
        tiles.add(
            ListTile(
              title: Text(L10().barcodeScanItem),
              subtitle: Text(L10().barcodeScanInItems),
              leading: FaIcon(FontAwesomeIcons.exchangeAlt, color: COLOR_CLICK),
              trailing: Icon(Icons.qr_code, color: COLOR_CLICK),
              onTap: () {

                var _loc = location;

                if (_loc != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>
                          InvenTreeQRView(
                              StockLocationScanInItemsHandler(_loc)))
                  ).then((value) {
                    refresh(context);
                  });
                }
              },
            )
        );

        // Scan this location into another one
        if (InvenTreeAPI().checkPermission("stock_location", "change")) {
          tiles.add(
            ListTile(
              title: Text(L10().transferStockLocation),
              subtitle: Text(L10().transferStockLocationDetail),
              leading: FaIcon(FontAwesomeIcons.signInAlt, color: COLOR_CLICK),
              trailing: Icon(Icons.qr_code, color: COLOR_CLICK),
              onTap: () {
                var _loc = location;

                if (_loc != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>
                          InvenTreeQRView(
                              ScanParentLocationHandler(_loc)))
                  ).then((value) {
                    refresh(context);
                  });
                }
              }
            )
          );
        }

        if (InvenTreeAPI().supportModernBarcodes) {
          tiles.add(
            customBarcodeActionTile(context, location!.customBarcode, "stocklocation", location!.pk)
          );
        }
      }
    }

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
