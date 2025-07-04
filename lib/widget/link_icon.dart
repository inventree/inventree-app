/*
 * An icon component to indicate that pressing on an item will change the page.
 */


import "package:flutter/cupertino.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";

Widget LinkIcon({
  bool external = false,
  String? text,
}) {

  // Return a row of items with an icon and text
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (text != null) ...[
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
      Icon(
        external ? TablerIcons.external_link : TablerIcons.chevron_right,
        color: COLOR_ACTION
      ),
    ],
  );
}