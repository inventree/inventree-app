/*
 * A set of helper functions to reduce boilerplate code
 */

/*
 * Simplify a numerical value into a string,
 * supressing trailing zeroes
 */

import "dart:io";
import "package:currency_formatter/currency_formatter.dart";
import "package:flutter/cupertino.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/progress.dart";
import "package:one_context/one_context.dart";
import "package:url_launcher/url_launcher.dart";
import "package:audioplayers/audioplayers.dart";

import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";

import "api_form.dart";



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

/*
 * Select a particular label, from a provided list of options,
 * and print against the selected instances.
 */
Future<void> selectAndPrintLabel(
    BuildContext context,
    List<Map<String, dynamic>> labels,
    String labelType,
    String labelQuery,
) async {

  // Find a list of available plugins which support label printing
  var plugins = InvenTreeAPI().getPlugins(mixin: "labels");

  dynamic initial_label;
  dynamic initial_plugin;

  List<Map<String, dynamic>> label_options = [];
  List<Map<String, dynamic>> plugin_options = [];

  // Construct list of available label templates
  for (var label in labels) {
    String display_name = (label["description"] ?? "").toString();
    int pk = (label["pk"] ?? -1) as int;

    if (display_name.isNotEmpty && pk > 0) {
      label_options.add({
        "display_name": display_name,
        "value": pk,
      });
    }
  }

  if (label_options.length == 1) {
    initial_label = label_options.first["value"];
  }

  // Construct list of available plugins
  for (var plugin in plugins) {
    plugin_options.add({
      "display_name": plugin.humanName,
      "value": plugin.key
    });
  }

  if (plugin_options.length == 1) {
    initial_plugin = plugin_options.first["value"];
  }

  Map<String, dynamic> fields = {
    "label": {
      "label": L10().labelTemplate,
      "type": "choice",
      "value": initial_label,
      "choices": label_options,
      "required": true,
    },
    "plugin": {
      "label": L10().pluginPrinter,
      "type": "choice",
      "value": initial_plugin,
      "choices": plugin_options,
      "required": true,
    }
  };

  launchApiForm(
    context,
    L10().printLabel,
    "",
    fields,
    icon: FontAwesomeIcons.print,
    onSuccess: (Map<String, dynamic> data) async {
      int labelId = (data["label"] ?? -1) as int;
      String pluginKey = (data["plugin"] ?? "") as String;

      if (labelId != -1 && pluginKey.isNotEmpty) {
        String url = "/label/${labelType}/${labelId}/print/?${labelQuery}&plugin=${pluginKey}";

        showLoadingOverlay(context);

        InvenTreeAPI().get(url).then((APIResponse response) {
          hideLoadingOverlay();
          if (response.isValid() && response.statusCode == 200) {

            var data = response.asMap();

            if (data.containsKey("file")) {
              var label_file = (data["file"] ?? "") as String;

              // Attempt to open remote file
              InvenTreeAPI().downloadFile(label_file);
            } else {
              showSnackIcon(
                  L10().printLabelSuccess,
                  success: true
              );
            }
          } else {
            showSnackIcon(
              L10().printLabelFailure,
              success: false,
            );
          }
        });
      }
    },
  );
}