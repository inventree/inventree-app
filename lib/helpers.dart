/*
 * A set of helper functions to reduce boilerplate code
 */

/*
 * Simplify a numerical value into a string,
 * supressing trailing zeroes
 */

import "package:audioplayers/audioplayers.dart";
import "package:inventree/app_settings.dart";

String simpleNumberString(double number) {
  // Ref: https://stackoverflow.com/questions/55152175/how-to-remove-trailing-zeros-using-dart

  return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1);
}

Future<void> successTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    final player = AudioCache();
    player.play("sounds/barcode_scan.mp3");
  }
}

Future <void> failureTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    final player = AudioCache();
    player.play("sounds/barcode_error.mp3");
  }
}