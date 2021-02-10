
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

void showSnackIcon(GlobalKey<ScaffoldState> key, String text, {IconData icon, bool success}) {

  // If icon not specified, use the success status
  if (icon == null) {
    icon = (success == true) ? FontAwesomeIcons.checkCircle : FontAwesomeIcons.timesCircle;
  }

  key.currentState.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Text(text),
          Spacer(),
          FaIcon(icon)
        ]
      ),
    )
  );
}