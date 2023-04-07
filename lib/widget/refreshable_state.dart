import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/barcode.dart";

import "package:inventree/widget/back.dart";
import "package:inventree/widget/drawer.dart";
import "package:inventree/widget/search.dart";


/*
 * Simple mixin class which defines simple methods for defining widget properties
 */
mixin BaseWidgetProperties {

  // Return a list of appBar actions
  List<Widget> getAppBarActions(BuildContext context) {
    List<Widget> actions = [
      IconButton(
        icon: Icon(Icons.search),
        onPressed: () async {
          // Open global search widget
          if (!InvenTreeAPI().checkConnection()) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchWidget(true)
            )
          );
        }
      ),
      IconButton(
        icon: Icon(Icons.qr_code_scanner),
        onPressed: () async {
          // Open barcode scan widget
          if (!InvenTreeAPI().checkConnection()) return;

          scanQrCode(context);
        },
      )
    ];

    return actions;
  }

  // Return a title for the appBar
  String getAppBarTitle(BuildContext context) { return "--- app bar ---"; }

  // Function to construct a drawer (override if needed)
  Widget getDrawer(BuildContext context) {
    return InvenTreeDrawer(context);
  }

  // Function to construct a body (MUST BE PROVIDED)
  Widget getBody(BuildContext context) {

    // Default return is an empty ListView
    return ListView();
  }

  Widget? getBottomNavBar(BuildContext context) {
    return null;
  }

  AppBar? buildAppBar(BuildContext context, GlobalKey<ScaffoldState> key) {
    return AppBar(
      title: Text(getAppBarTitle(context)),
      actions: getAppBarActions(context),
      leading: backButton(context, key),
    );
  }

  /*
   * Build out a set of SpeedDialChild widgets, to serve as "actions" for this view
   * Should be re-implemented by particular view with the required actions
   * By default, returns an empty list, and thus nothing will be rendered
   */
  List<SpeedDialChild> buildActionButtons(BuildContext context) => [];

  /*
   * Build out a set of barcode actions available for this view
   */
  List<SpeedDialChild> buildBarcodeButtons(BuildContext context) => [];

  /*
   * Build out action buttons for a given widget
   */
  Widget? buildSpeedDial(BuildContext context) {

    final actions = buildActionButtons(context);
    final barcodeActions = buildBarcodeButtons(context);

    if (actions.isEmpty && barcodeActions.isEmpty) {
      return null;
    }

    List<Widget> children = [];

    if (barcodeActions.isNotEmpty) {
      children.add(
        SpeedDial(
          icon: Icons.qr_code_scanner,
          activeIcon: Icons.close,
          children: barcodeActions,
          spacing: 14,
          childPadding: const EdgeInsets.all(5),
          spaceBetweenChildren: 15,
        )
      );
    }

    if (actions.isNotEmpty) {
      children.add(
          SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            children: actions,
            spacing: 14,
            childPadding: const EdgeInsets.all(5),
            spaceBetweenChildren: 15,
          )
      );
    }

    return Wrap(
      direction: Axis.vertical,
      children: children,
      spacing: 15,
    );
  }

}


/*
 * Abstract base class which provides generic "refresh" functionality.
 *
 * - Drag down and release to 'refresh' the widget
 * - Define some method which runs to 'refresh' the widget state
 */
abstract class RefreshableState<T extends StatefulWidget> extends State<T> with BaseWidgetProperties {

  final refreshableKey = GlobalKey<ScaffoldState>();

  // Storage for context once "Build" is called
  late BuildContext? _context;

  // Current tab index (used for widgets which display bottom tabs)
  int tabIndex = 0;

  // Bool indicator
  bool loading = false;

  bool get loaded => !loading;

  // Helper function to return API instance
  InvenTreeAPI get api => InvenTreeAPI();

  // Update current tab selection
  void onTabSelectionChanged(int index) {

    if (mounted) {
      setState(() {
        tabIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => onBuild(_context!));
  }

  // Function called after the widget is first build
  Future<void> onBuild(BuildContext context) async {
    refresh(context);
  }

  // Function to request data for this page
  Future<void> request(BuildContext context) async {
    return;
  }

  // Refresh the widget - handler for custom request() method
  Future<void> refresh(BuildContext context) async {

    // Escape if the widget is no longer loaded
    if (!mounted) {
      return;
    }

    setState(() {
      loading = true;
    });

    await request(context);

    // Escape if the widget is no longer loaded
    if (!mounted) {
      return;
    }

    setState(() {
      loading = false;
    });
  }

  BottomAppBar? buildBottomAppBar(BuildContext context) {

    List<Widget> icons = [];

    if (icons.isEmpty) {
      return null;
    }

    return BottomAppBar(
      color: Colors.redAccent,
      shape: CircularNotchedRectangle(),
      notchMargin: 5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: icons,
      )
    );
  }

  @override
  Widget build(BuildContext context) {

    // Save the context for future use
    _context = context;

    BottomAppBar? appBar = buildBottomAppBar(context);

    return Scaffold(
      key: refreshableKey,
      appBar: buildAppBar(context, refreshableKey),
      drawer: getDrawer(context),
      floatingActionButton: buildSpeedDial(context),
      floatingActionButtonLocation: appBar == null ? FloatingActionButtonLocation.endFloat : FloatingActionButtonLocation.endDocked,
      body: Builder(
        builder: (BuildContext context) {
          return RefreshIndicator(
              onRefresh: () async {
                refresh(context);
              },
              child: getBody(context)
          );
        }
      ),
      bottomNavigationBar: buildBottomAppBar(context),
      //getBottomNavBar(context),
    );
  }
}