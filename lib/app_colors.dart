import "dart:ui";
import "package:flutter/material.dart";
import "package:one_context/one_context.dart";

const Color COLOR_GRAY_LIGHT = Color.fromRGBO(150, 150, 150, 1);

// Return an "action" color based on the current theme
Color get COLOR_ACTION {

  BuildContext? context = OneContext().context;

  if (context != null) {
    return Theme.of(context).indicatorColor;
  } else {
    return Colors.lightBlue;
  }
}

const Color COLOR_BLUE = Color.fromRGBO(0, 0, 250, 1);

const Color COLOR_STAR = Color.fromRGBO(250, 250, 100, 1);

const Color COLOR_WARNING = Color.fromRGBO(250, 150, 50, 1);
const Color COLOR_DANGER = Color.fromRGBO(250, 50, 50, 1);
const Color COLOR_SUCCESS = Color.fromRGBO(50, 250, 50, 1);
const Color COLOR_PROGRESS = Color.fromRGBO(50, 50, 250, 1);

const Color COLOR_SELECTED = Color.fromRGBO(0, 0, 0, 0.05);