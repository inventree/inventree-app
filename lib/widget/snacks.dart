
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

void showSnackIcon(String text, {IconData icon, Function onTap, bool success}) {

  OneContext().hideCurrentSnackBar();

  Color backgroundColor;

  // Make some selections based on the "success" value
  if (success == true) {
    backgroundColor = Colors.lightGreen;

    // Unspecified icon?
    if (icon == null) {
      icon = FontAwesomeIcons.checkCircle;
    }

  } else if (success == false) {
    backgroundColor = Colors.deepOrange;

    if (icon == null) {
      icon = FontAwesomeIcons.timesCircle;
    }

  }

  OneContext().showSnackBar(builder: (context) => SnackBar(
    content: GestureDetector(
      child: Row(
        children: [
          Text(text),
          Spacer(),
          FaIcon(icon)
        ],
      ),
      onTap: onTap,
    ),
    backgroundColor: backgroundColor,
  ));

}