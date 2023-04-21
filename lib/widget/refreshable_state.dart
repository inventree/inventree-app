import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode.dart";

import "package:inventree/widget/back.dart";
import "package:inventree/widget/drawer.dart";
import "package:inventree/widget/search.dart";


/*
 * Simple mixin class which defines simple methods for defining widget properties
 */
mixin BaseWidgetProperties {

  /*
   * Return a list of appBar actions
   * By default, no appBar actions are available
   */
  List<Widget> appBarActions(BuildContext context) => [];

  // Return a title for the appBar
  String getAppBarTitle() { return "--- app bar ---"; }

  // Function to construct a drawer (override if needed)
  Widget getDrawer(BuildContext context) {
    return InvenTreeDrawer(context);
  }

  // Function to construct a set of tabs for this widget (override if needed)
  List<Widget> getTabs(BuildContext context) => [];

  // Function to construct a set of tiles for this widget (override if needed)
  List<Widget> getTiles(BuildContext context) => [];

  // Function to construct a body
  Widget getBody(BuildContext context) {

    // Default body calls getTiles()
    return Column(
      children: getTiles(context)
    );
  }


  /*
   * Construct the top AppBar for this view
   */
  AppBar? buildAppBar(BuildContext context, GlobalKey<ScaffoldState> key) {

    List<Widget> tabs = getTabIcons(context);

    return AppBar(
      centerTitle: false,
      bottom: tabs.isEmpty ? null : TabBar(tabs: tabs),
      title: Text(getAppBarTitle()),
      actions: appBarActions(context),
      leading: backButton(context, key),
    );
  }

  /*
   * Construct a global navigation bar at the bottom of the screen
   * - Button to access navigation menu
   * - Button to access global search
   * - Button to access barcode scan
   */
  BottomAppBar? buildBottomAppBar(BuildContext context, GlobalKey<ScaffoldState> key) {

    const double iconSize = 32;

    List<Widget> icons = [
      IconButton(
        icon: Icon(Icons.menu, color: COLOR_ACTION),
        iconSize: iconSize,
        onPressed: () {
          if (key.currentState != null) {
            key.currentState!.openDrawer();
          }
        },
      ),
      IconButton(
        icon: Icon(Icons.search, color: COLOR_ACTION),
        iconSize: iconSize,
        onPressed: () {
          if (InvenTreeAPI().checkConnection()) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SearchWidget(true)
                )
            );
          }
        },
      ),
      IconButton(
        icon: Icon(Icons.qr_code_scanner, color: COLOR_ACTION),
        iconSize: iconSize,
        onPressed: () {
          if (InvenTreeAPI().checkConnection()) {
            scanQrCode(context);
          }
        },
      )
    ];

    return BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 20,
        child: IconTheme(
            data: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: icons,
            )
        )
    );
  }

  /*
   * Build out a set of SpeedDialChild widgets, to serve as "actions" for this view
   * Should be re-implemented by particular view with the required actions
   * By default, returns an empty list, and thus nothing will be rendered
   */
  List<SpeedDialChild> actionButtons(BuildContext context) => [];

  /*
   * Build out a set of barcode actions available for this view
   */
  List<SpeedDialChild> barcodeButtons(BuildContext context) => [];

  /*
   * Build out action buttons for a given widget
   */
  Widget? buildSpeedDial(BuildContext context) {

    final actions = actionButtons(context);
    final barcodeActions = barcodeButtons(context);

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
            icon: Icons.more_horiz,
            activeIcon: Icons.close,
            children: actions,
            spacing: 14,
            childPadding: const EdgeInsets.all(5),
            spaceBetweenChildren: 15,
          )
      );
    }

    return Wrap(
      direction: Axis.horizontal,
      children: children,
      spacing: 15,
    );
  }

  // Return list of "tabs" for this widget
  List<Widget> getTabIcons(BuildContext context) => [];

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

  // Bool indicator
  bool loading = false;

  bool get loaded => !loading;

  // Helper function to return API instance
  InvenTreeAPI get api => InvenTreeAPI();

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

  @override
  Widget build(BuildContext context) {

    // Save the context for future use
    _context = context;

    List<Widget> tabs = getTabIcons(context);

    Widget body = tabs.isEmpty ? getBody(context) : TabBarView(children: getTabs(context));

    Scaffold view = Scaffold(
      key: refreshableKey,
      appBar: buildAppBar(context, refreshableKey),
      drawer: getDrawer(context),
      floatingActionButton: buildSpeedDial(context),
      floatingActionButtonLocation: FloatingActionButtonLocation
          .miniEndDocked,
      body: RefreshIndicator(
        onRefresh: () async {
          refresh(context);
        },
        child: body
      ),
      bottomNavigationBar: buildBottomAppBar(context, refreshableKey),
    );

    // Default implementation is *not* tabbed
    if (tabs.isNotEmpty) {
      return DefaultTabController(
          length: tabs.length,
          child: view,
      );
    } else {
      return view;
    }
  }
}