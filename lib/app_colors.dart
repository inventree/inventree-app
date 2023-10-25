import "package:flutter/material.dart";
import "package:one_context/one_context.dart";

const Color COLOR_GRAY_LIGHT = Color.fromRGBO(150, 150, 150, 1);

// Return an "action" color based on the current theme
Color get COLOR_ACTION {

  // OneContext might not have context, e.g. in testing
  if (!OneContext.hasContext) {
    return Colors.lightBlue;
  }

  BuildContext? context = OneContext().context;

  if (context != null) {
    return Theme.of(context).indicatorColor;
  } else {
    return Colors.lightBlue;
  }
}

const Color COLOR_WARNING = Color.fromRGBO(250, 150, 50, 1);
const Color COLOR_DANGER = Color.fromRGBO(200, 50, 75, 1);
const Color COLOR_SUCCESS = Color.fromRGBO(100, 200, 75, 1);
const Color COLOR_PROGRESS = Color.fromRGBO(50, 100, 200, 1);
