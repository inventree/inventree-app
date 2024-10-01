import "package:adaptive_theme/adaptive_theme.dart";
import "package:flutter/material.dart";
import "package:inventree/helpers.dart";
import "package:one_context/one_context.dart";

bool isDarkMode() {

  if (!hasContext()) {
    return false;
  }

  BuildContext? context = OneContext().context;

  if (context == null) {
    return false;
  }

  return AdaptiveTheme.of(context).brightness == Brightness.dark;
}

// Return an "action" color based on the current theme
Color get COLOR_ACTION {
  if (isDarkMode()) {
    return Colors.lightBlueAccent;
  } else {
    return Colors.blue;
  }
}

const Color COLOR_WARNING = Color.fromRGBO(250, 150, 50, 1);
const Color COLOR_DANGER = Color.fromRGBO(200, 50, 75, 1);
const Color COLOR_SUCCESS = Color.fromRGBO(100, 200, 75, 1);
const Color COLOR_PROGRESS = Color.fromRGBO(50, 100, 200, 1);
const Color COLOR_GRAY_LIGHT = Color.fromRGBO(150, 150, 150, 1);
