/*
 * A custom implementation of a "Back" button for display in the app drawer
 *
 * Long-pressing on this will return the user to the home screen
 */

import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";

import "package:inventree/widget/drawer.dart";

Widget backButton(BuildContext context, GlobalKey<ScaffoldState> key) {

  return GestureDetector(
    onLongPress: () {
      // Display the menu
      key.currentState!.openDrawer();
      print("hello?");
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