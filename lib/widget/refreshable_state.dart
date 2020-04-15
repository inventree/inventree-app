import 'package:InvenTree/widget/drawer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:InvenTree/widget/drawer.dart';


abstract class RefreshableState<T extends StatefulWidget> extends State<T> {

  // Storage for context once "Build" is called
  BuildContext context;

  String getAppBarTitle(BuildContext context) { return "App Bar Title"; }

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => request(context));
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
      title: Text(getAppBarTitle(context))
    );
  }

  // Function to construct a drawer (override if needed)
  Widget getDrawer(BuildContext context) {
    return InvenTreeDrawer(context);
  }

  // Function to construct a body (MUST BE PROVIDED)
  Widget getBody(BuildContext context);

  @override
  Widget build(BuildContext context) {

    // Save the context for future use
    this.context = context;

    return Scaffold(
      appBar: getAppBar(context),
      drawer: getDrawer(context),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: getBody(context)
      )
    );
  }
}