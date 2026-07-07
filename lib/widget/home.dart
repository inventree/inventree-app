import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/update_check.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/transfer_order.dart";
import "package:inventree/preferences.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/select_server.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/widget/order/so_shipment_list.dart";

import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/drawer.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/part/part_list.dart";
import "package:inventree/widget/order/purchase_order_list.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/order/transfer_order_list.dart";
import "package:inventree/widget/build/build_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/company/company_list.dart";

/*
 * Build a small count badge with the given background/foreground colors,
 * or null if there is nothing to show.
 * Extracted as a top-level function (rather than a private State method) so it
 * can be unit tested in isolation, without needing a live API connection.
 */
Widget? _buildCountBadge(
  int? count, {
  required IconData icon,
  required Color background,
  required Color foreground,
}) {
  if (count == null || count <= 0) {
    return null;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: foreground),
        const SizedBox(width: 4),
        Text(count.toString(), style: TextStyle(color: foreground)),
      ],
    ),
  );
}

// "Overdue" is the urgent case - use the theme's error colors
Widget? buildOverdueBadge(BuildContext context, int? count) {
  final ColorScheme colors = Theme.of(context).colorScheme;

  return _buildCountBadge(
    count,
    icon: TablerIcons.calendar_exclamation,
    background: colors.errorContainer,
    foreground: colors.onErrorContainer,
  );
}

// "Outstanding" is informational rather than urgent - use a less serious color
Widget? buildOutstandingBadge(BuildContext context, int? count) {
  final ColorScheme colors = Theme.of(context).colorScheme;

  return _buildCountBadge(
    count,
    icon: TablerIcons.progress,
    background: colors.secondaryContainer,
    foreground: colors.onSecondaryContainer,
  );
}

/*
 * Combine the "outstanding" and "overdue" badges for a single tile into one
 * widget (side by side), or null if neither has anything to show.
 */
Widget? buildOrderBadges(
  BuildContext context, {
  int? outstandingCount,
  int? overdueCount,
}) {
  final List<Widget> badges = [];

  final Widget? outstanding = buildOutstandingBadge(context, outstandingCount);
  if (outstanding != null) {
    badges.add(outstanding);
  }

  final Widget? overdue = buildOverdueBadge(context, overdueCount);
  if (overdue != null) {
    if (badges.isNotEmpty) {
      badges.add(const SizedBox(width: 6));
    }
    badges.add(overdue);
  }

  if (badges.isEmpty) {
    return null;
  }

  return Row(mainAxisSize: MainAxisSize.min, children: badges);
}

class InvenTreeHomePage extends StatefulWidget {
  const InvenTreeHomePage({Key? key}) : super(key: key);

  @override
  _InvenTreeHomePageState createState() => _InvenTreeHomePageState();
}

class _InvenTreeHomePageState extends State<InvenTreeHomePage>
    with BaseWidgetProperties {
  _InvenTreeHomePageState() : super() {
    // Load display settings
    _loadSettings();

    // Initially load the profile and attempt server connection
    _loadProfile();

    // Check GitHub for a newer app version
    _checkForUpdate();

    InvenTreeAPI().registerCallback(() {
      if (mounted) {
        setState(() {
          // Reload the widget
        });
      }

      _loadOrderCounts();
    });
  }

  final homeKey = GlobalKey<ScaffoldState>();

  bool homeShowPo = false;
  bool homeShowSo = false;
  bool homeShowShipments = false;
  bool homeShowBuild = false;
  bool homeShowSubscribed = false;
  bool homeShowManufacturers = false;
  bool homeShowCustomers = false;
  bool homeShowSuppliers = false;
  bool homeShowTransfer = false;

  // Selected user profile
  UserProfile? _profile;

  // Order counts (null = not loaded / not visible)
  int? _buildOverdueCount;
  int? _buildOutstandingCount;
  int? _poOverdueCount;
  int? _poOutstandingCount;
  int? _soOverdueCount;
  int? _soOutstandingCount;
  int? _shipmentsPendingCount;
  int? _transferOverdueCount;
  int? _transferOutstandingCount;

  void _showParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)),
    );
  }

  void _showStarredParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PartList({"starred": "true"})),
    );
  }

  void _showStock(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)),
    );
  }

  void _showPurchaseOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseOrderListWidget(filters: {}),
      ),
    );
  }

  void _showSalesOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesOrderListWidget(filters: {}),
      ),
    );
  }

  void _showPendingShipments(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SOShipmentListWidget(
          title: L10().shipmentsPending,
          filters: {"order_outstanding": "true", "shipped": "false"},
        ),
      ),
    );
  }

  void _showTransferOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransferOrderListWidget(filters: {}),
      ),
    );
  }

  void _showBuildOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuildOrderListWidget(filters: {}),
      ),
    );
  }

  void _showSuppliers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CompanyListWidget(L10().suppliers, {"is_supplier": "true"}),
      ),
    );
  }

  /*
  void _showManufacturers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  */
  void _showCustomers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CompanyListWidget(L10().customers, {"is_customer": "true"}),
      ),
    );
  }

  void _selectProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InvenTreeSelectServerWidget()),
    ).then((context) {
      // Once we return
      _loadProfile();
    });
  }

  Future<void> _checkForUpdate() async {
    UpdateChecker().checkForUpdate().then((_) {
      if (mounted) {
        setState(() {
          // Update the display if a new version is available
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    homeShowSubscribed =
        await InvenTreeSettingsManager().getValue(
              INV_HOME_SHOW_SUBSCRIBED,
              true,
            )
            as bool;
    homeShowPo =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_PO, true)
            as bool;
    homeShowSo =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SO, true)
            as bool;

    homeShowShipments =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SHIPMENTS, true)
            as bool;

    homeShowBuild =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_BUILD, true)
            as bool;

    homeShowManufacturers =
        await InvenTreeSettingsManager().getValue(
              INV_HOME_SHOW_MANUFACTURERS,
              true,
            )
            as bool;
    homeShowCustomers =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_CUSTOMERS, true)
            as bool;
    homeShowSuppliers =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SUPPLIERS, true)
            as bool;
    homeShowTransfer =
        await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_TRANSFER, true)
            as bool;

    setState(() {});

    _loadOrderCounts();
  }

  /*
   * Load the "overdue" and "outstanding" counts for build / purchase / sales orders,
   * to be displayed as badges against the relevant home screen tiles.
   * Only requests counts for tiles which are actually visible to the user.
   *
   * Each count is a separate cheap query (count() uses limit=1 server-side),
   * rather than fetching the full outstanding order list and counting locally -
   * that would require fetching *all* outstanding orders to be accurate.
   */
  Future<void> _loadOrderCounts() async {
    if (!InvenTreeAPI().isConnected()) {
      return;
    }

    final bool loadBuild =
        homeShowBuild && InvenTreeAPI().checkRole("build", "view");
    final bool loadPo = homeShowPo && InvenTreePurchaseOrder().canView;
    final bool loadSo = homeShowSo && InvenTreeSalesOrder().canView;
    final bool loadShipments =
        homeShowShipments && InvenTreeSalesOrderShipment().canView;
    final bool loadTransfer =
        homeShowTransfer &&
        InvenTreeAPI().supportsTransferOrders &&
        InvenTreeTransferOrder().canView;

    int? buildOverdue;
    int? buildOutstanding;
    int? poOverdue;
    int? poOutstanding;
    int? soOverdue;
    int? soOutstanding;
    int? shipmentsPending;
    int? transferOverdue;
    int? transferOutstanding;

    final List<Future<void>> requests = [];

    if (loadBuild) {
      requests.add(
        InvenTreeBuildOrder().count(filters: {"overdue": "true"}).then((c) {
          buildOverdue = c;
        }),
      );
      requests.add(
        InvenTreeBuildOrder().count(filters: {"outstanding": "true"}).then((c) {
          buildOutstanding = c;
        }),
      );
    }

    if (loadPo) {
      requests.add(
        InvenTreePurchaseOrder().count(filters: {"overdue": "true"}).then((c) {
          poOverdue = c;
        }),
      );
      requests.add(
        InvenTreePurchaseOrder().count(filters: {"outstanding": "true"}).then((
          c,
        ) {
          poOutstanding = c;
        }),
      );
    }

    if (loadSo) {
      requests.add(
        InvenTreeSalesOrder().count(filters: {"overdue": "true"}).then((c) {
          soOverdue = c;
        }),
      );
      requests.add(
        InvenTreeSalesOrder().count(filters: {"outstanding": "true"}).then((c) {
          soOutstanding = c;
        }),
      );
    }

    if (loadShipments) {
      requests.add(
        InvenTreeSalesOrderShipment()
            .count(filters: {"order_outstanding": "true", "shipped": "false"})
            .then((c) {
              shipmentsPending = c;
            }),
      );
    }

    if (loadTransfer) {
      requests.add(
        InvenTreeTransferOrder().count(filters: {"overdue": "true"}).then((c) {
          transferOverdue = c;
        }),
      );
      requests.add(
        InvenTreeTransferOrder().count(filters: {"outstanding": "true"}).then((
          c,
        ) {
          transferOutstanding = c;
        }),
      );
    }

    await Future.wait(requests);

    if (!mounted) {
      return;
    }

    setState(() {
      _buildOverdueCount = buildOverdue;
      _buildOutstandingCount = buildOutstanding;
      _poOverdueCount = poOverdue;
      _poOutstandingCount = poOutstanding;
      _soOverdueCount = soOverdue;
      _soOutstandingCount = soOutstanding;
      _shipmentsPendingCount = shipmentsPending;
      _transferOverdueCount = transferOverdue;
      _transferOutstandingCount = transferOutstanding;
    });
  }

  Future<void> _loadProfile() async {
    _profile = await UserProfileDBManager().getSelectedProfile();

    // A valid profile was loaded!
    if (_profile != null) {
      if (!InvenTreeAPI().isConnected() && !InvenTreeAPI().isConnecting()) {
        // Attempt server connection
        InvenTreeAPI().connectToServer(_profile!).then((result) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }

    setState(() {});
  }

  Widget _listTile(
    BuildContext context,
    String label,
    IconData icon, {
    Function()? callback,
    String role = "",
    String permission = "",
    Widget? trailing,
  }) {
    bool connected = InvenTreeAPI().isConnected();

    bool allowed = true;

    if (role.isNotEmpty || permission.isNotEmpty) {
      allowed = InvenTreeAPI().checkRole(role, permission);
    }

    return GestureDetector(
      child: Card(
        margin: EdgeInsets.all(5),
        child: Align(
          child: ListTile(
            leading: Icon(
              icon,
              color: connected && allowed ? COLOR_ACTION : COLOR_GRAY_LIGHT,
            ),
            title: Text(label),
            trailing: trailing,
          ),
          alignment: Alignment.center,
        ),
      ),
      onTap: () {
        if (!allowed) {
          showSnackIcon(
            L10().permissionRequired,
            icon: TablerIcons.exclamation_circle,
            success: false,
          );
          return;
        }

        if (callback != null) {
          callback();
        }
      },
    );
  }

  /*
   * Constructs a list of tiles for the main screen
   */
  List<Widget> getListTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Parts
    if (InvenTreePart().canView) {
      tiles.add(
        _listTile(
          context,
          L10().parts,
          TablerIcons.box,
          callback: () {
            _showParts(context);
          },
        ),
      );
    }

    // Starred parts
    if (homeShowSubscribed && InvenTreePart().canView) {
      tiles.add(
        _listTile(
          context,
          L10().partsStarred,
          TablerIcons.bell,
          callback: () {
            _showStarredParts(context);
          },
        ),
      );
    }

    // Stock button
    if (InvenTreeStockItem().canView) {
      tiles.add(
        _listTile(
          context,
          L10().stock,
          TablerIcons.package,
          callback: () {
            _showStock(context);
          },
        ),
      );
    }

    // Build Orders
    if (homeShowBuild && InvenTreeAPI().checkRole("build", "view")) {
      tiles.add(
        _listTile(
          context,
          L10().buildOrders,
          TablerIcons.building_factory,
          callback: () {
            _showBuildOrders(context);
          },
          role: "build",
          permission: "view",
          trailing: buildOrderBadges(
            context,
            outstandingCount: _buildOutstandingCount,
            overdueCount: _buildOverdueCount,
          ),
        ),
      );
    }

    // Transfer orders
    if (homeShowTransfer &&
        InvenTreeAPI().supportsTransferOrders &&
        InvenTreeTransferOrder().canView) {
      tiles.add(
        _listTile(
          context,
          L10().transferOrders,
          TablerIcons.transfer,
          callback: () {
            _showTransferOrders(context);
          },
          trailing: buildOrderBadges(
            context,
            outstandingCount: _transferOutstandingCount,
            overdueCount: _transferOverdueCount,
          ),
        ),
      );
    }

    // Purchase orders
    if (homeShowPo && InvenTreePurchaseOrder().canView) {
      tiles.add(
        _listTile(
          context,
          L10().purchaseOrders,
          TablerIcons.shopping_cart,
          callback: () {
            _showPurchaseOrders(context);
          },
          trailing: buildOrderBadges(
            context,
            outstandingCount: _poOutstandingCount,
            overdueCount: _poOverdueCount,
          ),
        ),
      );
    }

    if (homeShowSo && InvenTreeSalesOrder().canView) {
      tiles.add(
        _listTile(
          context,
          L10().salesOrders,
          TablerIcons.truck_delivery,
          callback: () {
            _showSalesOrders(context);
          },
          trailing: buildOrderBadges(
            context,
            outstandingCount: _soOutstandingCount,
            overdueCount: _soOverdueCount,
          ),
        ),
      );
    }

    if (homeShowShipments && InvenTreeSalesOrderShipment().canView) {
      tiles.add(
        _listTile(
          context,
          L10().shipmentsPending,
          TablerIcons.cube_send,
          callback: () {
            _showPendingShipments(context);
          },
          trailing: buildOutstandingBadge(context, _shipmentsPendingCount),
        ),
      );
    }

    // Suppliers
    if (homeShowSuppliers && InvenTreePurchaseOrder().canView) {
      tiles.add(
        _listTile(
          context,
          L10().suppliers,
          TablerIcons.building,
          callback: () {
            _showSuppliers(context);
          },
        ),
      );
    }

    // Customers
    if (homeShowCustomers) {
      tiles.add(
        _listTile(
          context,
          L10().customers,
          TablerIcons.building_store,
          callback: () {
            _showCustomers(context);
          },
        ),
      );
    }

    return tiles;
  }

  /*
   * If the app is not connected to an InvenTree server,
   * display a connection status widget
   */
  Widget _connectionStatusWidget(BuildContext context) {
    String? serverAddress = InvenTreeAPI().serverAddress;
    bool validAddress = serverAddress != null;
    bool connecting =
        !InvenTreeAPI().isConnected() && InvenTreeAPI().isConnecting();

    Widget leading = Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER);
    Widget trailing = Icon(TablerIcons.server, color: COLOR_ACTION);
    String title = L10().serverNotConnected;
    String subtitle = L10().profileSelectOrCreate;

    if (!validAddress) {
      title = L10().serverNotSelected;
    } else if (connecting) {
      title = L10().serverConnecting;
      subtitle = serverAddress;
      leading = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(color: COLOR_PROGRESS, strokeWidth: 2),
      );
    }

    return Center(
      child: Column(
        children: [
          Spacer(),
          Image.asset(
            "assets/image/logo_transparent.png",
            color: Colors.white.withValues(alpha: 0.05),
            colorBlendMode: BlendMode.modulate,
            scale: 0.5,
          ),
          Spacer(),
          ListTile(
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: trailing,
            leading: leading,
            onTap: _selectProfile,
          ),
        ],
      ),
    );
  }

  /*
   * Return the main body widget for display
   */
  @override
  Widget getBody(BuildContext context) {
    if (!InvenTreeAPI().isConnected()) {
      return _connectionStatusWidget(context);
    }

    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;

    bool smallScreen = max(w, h) < 1000;

    int vTiles = smallScreen ? 2 : 3;
    int hTiles = smallScreen ? 1 : 2;
    double aspect = smallScreen ? 5 : 3;
    double padding = smallScreen ? 2 : 10;

    return GridView.count(
      crossAxisCount: w > h ? vTiles : hTiles,
      children: getListTiles(context),
      childAspectRatio: aspect,
      primary: false,
      // Ensure the grid is always draggable, even if the tiles don't fill the viewport,
      // so that "pull down to refresh" works regardless of screen size / tile count
      physics: const AlwaysScrollableScrollPhysics(),
      crossAxisSpacing: padding,
      mainAxisSpacing: padding,
      padding: EdgeInsets.all(padding),
    );
  }

  // Refresh handler for "pull down to refresh" on the home screen
  Future<void> _onRefresh() async {
    await _loadProfile();
    await _loadOrderCounts();
  }

  @override
  Widget build(BuildContext context) {
    var connected = InvenTreeAPI().isConnected();
    var connecting = !connected && InvenTreeAPI().isConnecting();

    return Scaffold(
      key: homeKey,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/image/logo_transparent.png", height: 24),
            SizedBox(width: 8),
            Text(L10().appTitle),
          ],
        ),
        actions: [
          InkWell(
            onTap: _selectProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (connected &&
                      (InvenTreeAPI().profile?.name ?? "").isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          InvenTreeAPI().profile!.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  Stack(
                    children: [
                      Icon(TablerIcons.server),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: connected
                                ? COLOR_SUCCESS
                                : (connecting ? COLOR_PROGRESS : COLOR_DANGER),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: InvenTreeDrawer(context),
      body: RefreshIndicator(onRefresh: _onRefresh, child: getBody(context)),
      bottomNavigationBar: InvenTreeAPI().isConnected()
          ? buildBottomAppBar(context, homeKey)
          : null,
    );
  }
}
