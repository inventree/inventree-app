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

// Resolve the app's current ColorScheme, falling back to a sensible default
// if no BuildContext is available yet (e.g. very early app startup).
ColorScheme get _colorScheme {
  final BuildContext? context = OneContext().context;

  if (context == null) {
    return const ColorScheme.light();
  }

  return Theme.of(context).colorScheme;
}

// Semantic colors, derived from the current theme's ColorScheme.
// Material 3 has no dedicated "success"/"warning" roles, so those map onto
// the nearest available accent (tertiary / secondary respectively).
Color get COLOR_ACTION => Colors.blue;
Color get COLOR_WARNING => Colors.orange;
Color get COLOR_DANGER => _colorScheme.error;
Color get COLOR_SUCCESS => Colors.lightGreen;
Color get COLOR_PROGRESS => Colors.lightBlue;
Color get COLOR_GRAY_LIGHT => _colorScheme.onSurfaceVariant;
Color get COLOR_TEXT => _colorScheme.onSurface;
