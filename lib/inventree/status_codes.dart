/*
 * Code for querying the server for various status code data,
 * so that we do not have to duplicate those codes in the app.
 *
 * Ref: https://github.com/inventree/InvenTree/blob/master/InvenTree/InvenTree/status_codes.py
 */

import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";


/*
 * Base class definition for a "status code" definition.
 */
class InvenTreeStatusCode {

  InvenTreeStatusCode(this.URL);

  final String URL;

  // Internal status code data loaded from server
  Map<String, dynamic> data = {};

  /*
   * Construct a list of "choices" suitable for a form
   */
  List<dynamic> get choices {
    List<dynamic> _choices = [];

    for (String key in data.keys) {
      dynamic _entry = data[key];

      if (_entry is Map<String, dynamic>) {
        _choices.add({
          "value": _entry["key"],
          "display_name": _entry["label"]
        });
      }
    }

    return _choices;
  }

  // Load status code information from the server
  Future<void> load({bool forceReload = false}) async {

    // Return internally cached data
    if (data.isNotEmpty && !forceReload) {
      return;
    }

    // The server must support this feature!
    if (!InvenTreeAPI().supportsStatusLabelEndpoints) {
      return;
    }

    debug("Loading status codes from ${URL}");

    APIResponse response = await InvenTreeAPI().get(URL);

    if (response.statusCode == 200) {
      Map<String, dynamic> results = response.data as Map<String, dynamic>;

      if (results.containsKey("values")) {
        data = results["values"] as Map<String, dynamic>;
      }
    }
  }

  // Return the entry associated with the provided integer status
  Map<String, dynamic> entry(int status) {
    for (String key in data.keys) {
      dynamic _entry = data[key];

      if (_entry is Map<String, dynamic>) {
        dynamic _status = _entry["key"];

        if (_status is int) {
          if (status == _status) {
            return _entry;
          }
        }
      }
    }

    // No match - return an empty map
    return {};
  }

  // Return the 'label' associated with a given status code
  String label(int status) {
    Map<String, dynamic> _entry = entry(status);

    String _label = (_entry["label"] ?? "") as String;

    if (_label.isEmpty) {
      // If no match found, return the status code
      debug("No match for status code ${status} at '${URL}'");
      return status.toString();
    } else {
      return _label;
    }
  }

  // Return the 'name' (untranslated) associated with a given status code
  String name(int status) {
    Map<String, dynamic> _entry = entry(status);

    String _name = (_entry["name"] ?? "") as String;

    if (_name.isEmpty) {
      debug("No match for status code ${status} at '${URL}'");
    }

    return _name;
  }

  // Test if the name associated with the given code is in the provided list
  bool isNameIn(int code, List<String> names) {
    return names.contains(name(code));
  }

  // Return the 'color' associated with a given status code
  Color color(int status) {
    Map<String, dynamic> _entry = entry(status);

    String color_name = (_entry["color"] ?? "") as String;

    switch (color_name.toLowerCase()) {
      case "success":
        return COLOR_SUCCESS;
      case "primary":
        return COLOR_PROGRESS;
      case "secondary":
        return Colors.grey;
      case "dark":
        return Colors.black;
      case "danger":
        return COLOR_DANGER;
      case "warning":
        return COLOR_WARNING;
      case "info":
        return Colors.lightBlue;
      default:
        return Colors.black;
    }
  }
}
