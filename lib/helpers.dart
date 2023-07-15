/*
 * A set of helper functions to reduce boilerplate code
 */

/*
 * Simplify a numerical value into a string,
 * supressing trailing zeroes
 */

import "dart:io";
import "package:currency_formatter/currency_formatter.dart";

import "package:one_context/one_context.dart";
import "package:url_launcher/url_launcher.dart";
import "package:audioplayers/audioplayers.dart";

import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";



List<String> debug_messages = [];

void clearDebugMessage() => debug_messages.clear();

int debugMessageCount() {
  print("Debug Messages: ${debug_messages.length}");
  return debug_messages.length;
}

// Check if the debug log contains a given message
bool debugContains(String msg, {bool raiseAssert = true}) {
  bool result = false;

  for (String element in debug_messages) {
    if (element.contains(msg)) {
      result = true;
      break;
    }
  }

  if (raiseAssert) {
    assert(result);
  }

  return result;
}

/*
 * Display a debug message if we are in testing mode, or running in debug mode
 */
void debug(dynamic msg) {

  if (Platform.environment.containsKey("FLUTTER_TEST")) {
    debug_messages.add(msg.toString());
  }

  print("DEBUG: ${msg.toString()}");
}


/*
 * Simplify string representation of a floating point value
 * Basically, don't display fractional component if it is an integer
 */
String simpleNumberString(double number) {

  if (number.toInt() == number) {
    return number.toInt().toString();
  } else {
    return number.toString();
  }
}

/*
 * Play an audio file from the requested path.
 *
 * Note: If OneContext module fails the 'hasContext' check,
 *       we will not attempt to play the sound
 */
Future<void> playAudioFile(String path) async {

  // Debug message for unit testing
  debug("Playing audio file: '${path}'");

  if (!OneContext.hasContext) {
    return;
  }

  final player = AudioPlayer();
  player.play(AssetSource(path));
}


// Open an external URL
Future<void> openLink(String url) async {

  final link = Uri.parse(url);

  try {
    await launchUrl(link);
  } catch (e) {
    showSnackIcon(L10().error, success: false);
  }
}


/*
 * Helper function for rendering a money / currency object as a String
 */
String renderCurrency(double? amount, String currency, {int decimals = 2}) {

  if (amount == null) return "-";
  if (amount.isInfinite || amount.isNaN) return "-";

  currency = currency.trim();

  if (currency.isEmpty) return "-";

  CurrencyFormatterSettings backupSettings = CurrencyFormatterSettings(
    symbol: "\$",
    symbolSide: SymbolSide.left,
  );

  String value = CurrencyFormatter.format(
    amount,
    CurrencyFormatter.majors[currency.toLowerCase()] ?? backupSettings
  );

  // If we were not able to determine the currency
  if (!CurrencyFormatter.majors.containsKey(currency.toLowerCase())) {
    value += " ${currency}";
  }

  return value;
}

