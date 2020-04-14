
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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