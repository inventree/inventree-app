import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_gen/gen_l10n/app_localizations_en.dart";

import "package:one_context/one_context.dart";
import "package:flutter/material.dart";

// Shortcut function to reduce boilerplate!
I18N L10()
{
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