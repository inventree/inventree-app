import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:one_context/one_context.dart";

import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

/*
 * Display a configurable 'snackbar' at the bottom of the screen
 */
void showSnackIcon(String text, {IconData? icon, Function()? onAction, bool? success, String? actionText}) {

  debug("showSnackIcon: '${text}'");

  // Escape quickly if we do not have context
  if (isTesting() || !OneContext.hasContext) {
    // Debug message for unit testing
    return;
  }

  BuildContext? context = OneContext().context;

  if (context != null) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  Color backgroundColor = Colors.deepOrange;

  // Make some selections based on the "success" value
  if (success != null && success == true) {
    backgroundColor = Colors.lightGreen;

    // Select an icon if we do not have an action
    if (icon == null && onAction == null) {
      icon = TablerIcons.circle_check;
    }

  } else if (success != null && success == false) {
    backgroundColor = Colors.deepOrange;

    if (icon == null && onAction == null) {
      icon = TablerIcons.exclamation_circle;
    }
  }

  String _action = actionText ?? L10().details;

  List<Widget> childs = [
    Text(text),
    Spacer(),
  ];

  if (icon != null) {
    childs.add(Icon(icon));
  }

  OneContext().showSnackBar(builder: (context) => SnackBar(
    content: GestureDetector(
      child: Row(
        children: childs
      ),
      onTap: () {
        ScaffoldMessenger.of(context!).hideCurrentSnackBar();
      },
    ),
    backgroundColor: backgroundColor,
    action: onAction == null ? null : SnackBarAction(
      label: _action,
      onPressed: () {
        // Immediately dismiss the notification
        ScaffoldMessenger.of(context!).hideCurrentSnackBar();
        onAction();
      }
    ),
    duration: Duration(seconds: onAction == null ? 1 : 2),
    )
  );

}