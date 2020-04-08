
import 'package:InvenTree/widget/drawer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SearchWidget extends StatefulWidget {

  @override
  _SearchState createState() => _SearchState();
}


class _SearchState extends State<SearchWidget> {

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("Search"),
      ),
      drawer: new InvenTreeDrawer(context),
      body: Center(
        child: ListView(
          children: <Widget>[

          ],
        )
      )
    );

  }
}