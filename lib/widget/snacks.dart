import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:one_context/one_context.dart";
import "package:inventree/l10.dart";


/*
 * Display a configurable 'snackbar' at the bottom of the screen
 */
void showSnackIcon(String text, {IconData? icon, Function()? onAction, bool? success, String? actionText}) {

  // Escape quickly if we do not have context
  if (!OneContext.hasContext) {
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
      icon = FontAwesomeIcons.checkCircle;
    }

  } else if (success != null && success == false) {
    backgroundColor = Colors.deepOrange;

    if (icon == null && onAction == null) {
      icon = FontAwesomeIcons.exclamationCircle;
    }
  }

  String _action = actionText ?? L10().details;

  SnackBarAction? action;

  if (onAction != null) {
    action = SnackBarAction(
      label: _action,
      onPressed: onAction,
    );
  }

  List<Widget> childs = [
    Text(text),
    Spacer(),
  ];

  if (icon != null) {
    childs.add(FaIcon(icon));
  }

  OneContext().showSnackBar(builder: (context) => SnackBar(
    content: Row(
        children: childs
    ),
    backgroundColor: backgroundColor,
    action: action
    )
  );

}