import "package:inventree/l10n/collected/app_localizations.dart";
import "package:inventree/l10n/collected/app_localizations_en.dart";

import "package:one_context/one_context.dart";
import "package:flutter/material.dart";

import "package:inventree/helpers.dart";

// Shortcut function to reduce boilerplate!
I18N L10() {
  // Testing mode - ignore context
  if (!hasContext()) {
    return I18NEn();
  }

  BuildContext? _ctx = OneContext().context;

  if (_ctx != null) {
    I18N? i18n = I18N.of(_ctx);

    if (i18n != null) {
      return i18n;
    }
  }

  // Fallback for "null" context
  return I18NEn();
}
