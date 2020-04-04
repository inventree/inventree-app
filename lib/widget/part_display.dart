
import 'package:InvenTree/inventree/part.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/widget/drawer.dart';

class PartDisplayWidget extends StatefulWidget {

  PartDisplayWidget(this.part, {Key key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartDisplayState createState() => _PartDisplayState(part);

}


class _PartDisplayState extends State<PartDisplayWidget> {

  _PartDisplayState(this.part) {
    // TODO
  }

  final InvenTreePart part;

  String get _title {
    if (part == null) {
      return "Part";
    } else {
      return "Part '${part.name}'";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      drawer: new InvenTreeDrawer(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Description: ${part.description}"),
          ]
        ),
      )
    );
  }
}