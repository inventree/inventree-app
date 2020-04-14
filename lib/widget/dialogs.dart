
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void showErrorDialog(BuildContext context, String title, String description) {
  showDialog(
    context: context,
    child: SimpleDialog(
      title: ListTile(
        title: Text("Error"),
        leading: FaIcon(FontAwesomeIcons.exclamationCircle),
      ),
      children: <Widget>[
        ListTile(
          title: Text(title),
          subtitle: Text(description)
        )
      ]
    )
  );
}

void showProgressDialog(BuildContext context, String title, String description) {
  showDialog(
    context: context,
    barrierDismissible: false,
    child: SimpleDialog(
      title: Text(title),
      children: <Widget>[
        CircularProgressIndicator(),
        Text(description),
      ],
    )
  );
}

void hideProgressDialog(BuildContext context) {
  Navigator.pop(context);
}