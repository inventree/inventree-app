import "package:flutter/material.dart";

/*
 * Construct a custom back button with special feature!
 *
 * Long-pressing on this will return the user to the home screen
 */
Widget backButton(BuildContext context, GlobalKey<ScaffoldState> key) {

  return GestureDetector(
    onLongPress: () {
      // Display the menu
      key.currentState!.openDrawer();
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