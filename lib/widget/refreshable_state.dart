import 'package:inventree/widget/drawer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';


abstract class RefreshableState<T extends StatefulWidget> extends State<T> {

  final refreshableKey = GlobalKey<ScaffoldState>();

  // Storage for context once "Build" is called
  BuildContext? _context;

  // Current tab index (used for widgets which display bottom tabs)
  int tabIndex = 0;

  // Bool indicator
  bool loading = false;

  bool get loaded => !loading;

  // Update current tab selection
  void onTabSelectionChanged(int index) {
    setState(() {
      tabIndex = index;
    });
  }

  List<Widget> getAppBarActions(BuildContext context) {
    return [];
  }

  String getAppBarTitle(BuildContext context) { return "App Bar Title"; }

  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) => onBuild(_context!));
  }

  // Function called after the widget is first build
  Future<void> onBuild(BuildContext context) async {
    refresh();
  }

  // Function to request data for this page
  Future<void> request() async {
    return;
  }

  Future<void> refresh() async {

    setState(() {
      loading = true;
    });

    await request();

    setState(() {
      loading = false;
    });
  }

  // Function to construct an appbar (override if needed)
  AppBar getAppBar(BuildContext context) {
    return AppBar(
      title: Text(getAppBarTitle(context)),
      actions: getAppBarActions(context),
    );
  }

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

  Widget? getFab(BuildContext context) {
    return null;
  }

  @override
  Widget build(BuildContext context) {

    // Save the context for future use
    _context = context;

    return Scaffold(
      key: refreshableKey,
      appBar: getAppBar(context),
      drawer: null, // getDrawer(context),
      floatingActionButton: getFab(context),
      body: Builder(
        builder: (BuildContext context) {
          return RefreshIndicator(
              onRefresh: refresh,
              child: getBody(context)
          );
        }
      ),
      bottomNavigationBar: getBottomNavBar(context),
    );
  }
}