/*
 * A custom implementation of a "Back" button for display in the app drawer
 *
 * Long-pressing on this will return the user to the home screen
 */

import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";

Widget backButton(BuildContext context) {

  return GestureDetector(
    onLongPress: () {
      while (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    },
    child: IconButton(
      icon: BackButtonIcon(),
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    ),
  );
}