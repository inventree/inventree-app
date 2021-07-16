
import 'package:inventree/api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FullScreenWidget extends StatelessWidget {

  // Remote URL for image
  String _url;

  // App bar title
  String _title;

  FullScreenWidget(this._title, this._url);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: InvenTreeAPI().getImage(_url),
    );
  }
}