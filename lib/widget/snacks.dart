
/*
 * Display a snackbar with:
 *
 * a) Text on the left
 * b) Icon on the right
 *
 * | Text          <icon> |
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:one_context/one_context.dart';

void showSnackIcon(String text, {IconData icon, Function onAction, bool success, String actionText}) {

  OneContext().hideCurrentSnackBar();

  Color backgroundColor;

  // Make some selections based on the "success" value
  if (success == true) {
    backgroundColor = Colors.lightGreen;

  } else if (success == false) {
    backgroundColor = Colors.deepOrange;
  }

  SnackBarAction action;

  if (onAction != null && actionText != null) {
    action = SnackBarAction(
      label: actionText,
      onPressed: onAction,
    );
  }

  List<Widget> childs = [
    Text(text),
    Spacer(),
  ];

  if (icon != null) {
    childs.add(FaIcon(icon));
  }

  OneContext().showSnackBar(builder: (context) => SnackBar(
    content: Row(
        children: childs
    ),
    backgroundColor: backgroundColor,
    action: action
    )
  );

}