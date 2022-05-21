/*
 * A set of helper functions to reduce boilerplate code
 */

/*
 * Simplify a numerical value into a string,
 * supressing trailing zeroes
 */

import "package:audioplayers/audioplayers.dart";
import "package:one_context/one_context.dart";

String simpleNumberString(double number) {
  // Ref: https://stackoverflow.com/questions/55152175/how-to-remove-trailing-zeros-using-dart

  return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1);
}

/*
 * Play an audio file from the requested path.
 *
 * Note: If OneContext module fails the 'hasConext' check,
 *       we will not attempt to play the sound
 */
Future<void> playAudioFile(String path) async {

  if (!OneContext.hasContext) {
    return;
  }

  final player = AudioCache();
  player.play(path);

}
