

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inventree/widget/refreshable_state.dart';

class NotificationWidget extends StatefulWidget {

  @override
  _NotificationState createState() => _NotificationState();

}


class _NotificationState extends RefreshableState<NotificationWidget> {

  _NotificationState() : super();

  @override
  AppBar? buildAppBar(BuildContext context) {
    // No app bar for the notification widget
    return null;
  }

  @override
  Future<void> request (BuildContext context) async {
    print("requesting notifications!");
  }

  List<Widget> renderNotifications(BuildContext context) {

    List<Widget> tiles = [];

    tiles.add(
      ListTile(
        title: Text("Not"),
        subtitle: Text("subtitle yatyayaya"),
      )
    );

    return tiles;

  }

  @override
  Widget getBody(BuildContext context) {
    return Center(
      child: ListView(
        children: ListTile.divideTiles(
          context: context,
          tiles: renderNotifications(context),
        ).toList()
      )
    );
  }

}