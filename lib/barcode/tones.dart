import "package:inventree/helpers.dart";
import "package:inventree/preferences.dart";

/*
 * Play an audible 'success' alert to the user.
 */
Future<void> barcodeSuccessTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    playAudioFile("sounds/barcode_scan.mp3");
  }
}

Future <void> barcodeFailureTone() async {

  final bool en = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;

  if (en) {
    playAudioFile("sounds/barcode_error.mp3");
  }
}