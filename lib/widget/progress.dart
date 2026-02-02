import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_overlay_loader/flutter_overlay_loader.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/widget/link_icon.dart";
import "package:one_context/one_context.dart";

/*
 * A simplified linear progress bar widget,
 * with standardized color depiction
 */
Widget ProgressBar(double value, {double maximum = 1.0}) {
  double v = 0;

  if (value <= 0 || maximum <= 0) {
    v = 0;
  } else {
    v = value / maximum;
  }

  return LinearProgressIndicator(
    value: v,
    backgroundColor: Colors.grey,
    color: v >= 1 ? COLOR_SUCCESS : COLOR_WARNING,
  );
}

Widget ProgressText(double value, {double maximum = 1.0}) {
  Color textColor = value < maximum ? COLOR_WARNING : COLOR_SUCCESS;

  String v = simpleNumberString(value);
  String m = simpleNumberString(maximum);

  return LargeText("${v} / ${m}", color: textColor);
}

/*
 * Construct a circular progress indicator
 */
Widget progressIndicator() {
  return Center(child: CircularProgressIndicator());
}

void showLoadingOverlay() {
  // Do not show overlay if running unit tests
  if (Platform.environment.containsKey("FLUTTER_TEST")) {
    return;
  }

  BuildContext? context = OneContext.hasContext ? OneContext().context : null;

  if (context == null) {
    return;
  }

  Loader.show(
    context,
    themeData: Theme.of(
      context,
    ).copyWith(colorScheme: ColorScheme.fromSwatch()),
  );
}

void hideLoadingOverlay() {
  if (Loader.isShown) {
    Loader.hide();
  }
}
