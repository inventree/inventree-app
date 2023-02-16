import "package:flutter/material.dart";

import "package:inventree/api.dart";

import "package:inventree/widget/back.dart";
import "package:inventree/widget/drawer.dart";


/*
 * Simple mixin class which defines simple methods for defining widget properties
 */
mixin BaseWidgetProperties {

  // Return a list of appBar actions (default = None)
  List<Widget> getAppBarActions(BuildContext context) => [];

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

  @override
  Widget build(BuildContext context) {

    // Save the context for future use
    _context = context;

    return Scaffold(
      key: refreshableKey,
      appBar: buildAppBar(context, refreshableKey),
      drawer: getDrawer(context),
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
      bottomNavigationBar: getBottomNavBar(context),
    );
  }
}