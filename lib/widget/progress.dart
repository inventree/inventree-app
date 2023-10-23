

import "package:flutter/material.dart";
import "package:flutter_overlay_loader/flutter_overlay_loader.dart";

/*
 * Construct a circular progress indicator
 */
Widget progressIndicator() {

  return Center(
    child: CircularProgressIndicator()
  );
}


void showLoadingOverlay(BuildContext? context) {

  if (context == null) {
    return;
  }

  Loader.show(
    context,
    themeData: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSwatch())
  );
}


void hideLoadingOverlay() {
  Loader.hide();
}
