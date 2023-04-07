import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

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
  String getAppBarTitle(BuildContext context) {
    return L10().stockLocation;
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    // Add "locate" button
    if (location != null && api.supportsMixin("locate")) {
      actions.add(
          IconButton(
              icon: Icon(Icons.travel_explore),
              tooltip: L10().locateLocation,
              onPressed: () async {
                api.locateItemOrLocation(context, location: location!.pk);
              }
          )
      );
    }

    // Add "edit" button
    if (location != null && api.checkPermission("stock_location", "change")) {
      actions.add(
          IconButton(
              icon: Icon(Icons.edit_square),
              tooltip: L10().editLocation,
              onPressed: () {
                _editLocationDialog(context);
              }
          )
      );
    }


    return actions;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (location != null) {
      // Scan items into this location
      if (api.checkPermission("stock", "change")) {
        actions.add(
            SpeedDialChild(
                child: FaIcon(FontAwesomeIcons.qrcode),
                label: L10().barcodeScanItem,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>
                          InvenTreeQRView(
                              StockLocationScanInItemsHandler(location!)))
                  ).then((value) {
                    refresh(context);
                  });
                }
            )
        );
      }

      // Scan this location into another one
      if (api.checkPermission("stock_location", "change")) {
        actions.add(
            SpeedDialChild(
                child: FaIcon(FontAwesomeIcons.qrcode),
                label: L10().transferStockLocation,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>
                          InvenTreeQRView(
                              ScanParentLocationHandler(location!)))
                  ).then((value) {
                    refresh(context);
                  });
                }
            )
        );
      }

      // Assign or un-assign barcodes
      if (api.supportModernBarcodes) {
        actions.add(
            customBarcodeAction(
                context, this,
                location!.customBarcode, "stocklocation",
                location!.pk
            )
        );
      }
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    // Create new location
    if (api.checkPermission("stock_location", "add")) {
      actions.add(
          SpeedDialChild(
              child: FaIcon(FontAwesomeIcons.sitemap),
              label: L10().locationCreate,
              onTap: () async {
                _newLocation(context);
              }
          )
      );
    }

    // Create new item
    if (location != null && api.checkPermission("stock", "add")) {
      actions.add(
          SpeedDialChild(
              child: FaIcon(FontAwesomeIcons.boxesStacked),
              label: L10().stockItemCreate,
              onTap: () async {
                _newStockItem(context);
              }
          )
      );
    }

    return actions;
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
            leading: FaIcon(FontAwesomeIcons.boxesStacked),
          )
      );
    } else {
      List<Widget> children = [
        ListTile(
          title: Text("${location!.name}"),
          subtitle: Text("${location!.description}"),
          leading: location!.customIcon ??
              FaIcon(FontAwesomeIcons.boxesStacked),
        ),
      ];

      if (includeActions) {
        children.add(
            ListTile(
              title: Text(L10().parentLocation),
              subtitle: Text("${location!.parentPathString}"),
              leading: FaIcon(FontAwesomeIcons.turnUp, color: COLOR_CLICK),
              onTap: () async {
                int parentId = location?.parentId ?? -1;

                if (parentId < 0) {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => LocationDisplayWidget(null)));
                } else {
                  showLoadingOverlay(context);
                  var loc = await InvenTreeStockLocation().get(parentId);
                  hideLoadingOverlay();

                  if (loc is InvenTreeStockLocation) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => LocationDisplayWidget(loc)));
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
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.sitemap),
            label: L10().details,
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.boxesStacked),
            label: L10().stock,
          ),
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
}
