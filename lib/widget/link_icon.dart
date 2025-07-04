/*
 * An icon component to indicate that pressing on an item will change the page.
 */

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";

Widget LargeText(
  String text, {
  double size = 14.0,
  bool bold = false,
  Color? color,
}) {
  // Return a large text widget with specified text
  return Text(
    text,
    style: TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    ),
  );
}

Widget LinkIcon({
  bool external = false,
  String? text,
  CachedNetworkImage? image,
}) {
  // Return a row of items with an icon and text
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (text != null) ...[LargeText(text)],
      if (image != null) ...[image],
      Icon(
        external ? TablerIcons.external_link : TablerIcons.chevron_right,
        color: COLOR_ACTION,
      ),
    ],
  );
}
