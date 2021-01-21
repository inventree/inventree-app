import 'package:InvenTree/widget/drawer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:InvenTree/widget/drawer.dart';


abstract class RefreshableState<T extends StatefulWidget> extends State<T> {

  // Storage for context once "Build" is called
  BuildContext context;

  List<Widget> getAppBarActions(BuildContext context) {
    return [];
  }

  String getAppBarTitle(BuildContext context) { return "App Bar Title"; }

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => onBuild(context));
  }

  // Function called after the widget is first build
  Future<void> onBuild(BuildContext context) async {
    refresh();
  }

  // Function to request data for this page
  Future<void> request(BuildContext context) async {
    return;
  }

  Future<void> refresh() async {
    await request(context);
    setState(() {});
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
    return null;
  }

  Widget getBottomNavBar(BuildContext context) {
    return null;
  }

  Widget getFab(BuildContext context) {
    return null;
  }

  @override
  Widget build(BuildContext context) {

    // Save the context for future use
    this.context = context;

    return Scaffold(
      appBar: getAppBar(context),
      drawer: getDrawer(context),
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