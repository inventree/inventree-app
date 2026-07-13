import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:one_context/one_context.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/preferences.dart";

/*
 * Launch a dialog allowing the user to select from a list of options
 */
Future<void> choiceDialog(
  String title,
  List<Widget> items, {
  Function? onSelected,
}) async {
  List<Widget> choices = [];

  for (int idx = 0; idx < items.length; idx++) {
    choices.add(
      GestureDetector(
        child: items[idx],
        onTap: () {
          OneContext().popDialog();
          if (onSelected != null) {
            onSelected(idx);
          }
        },
      ),
    );
  }

  if (!hasContext()) {
    return;
  }

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Column(children: choices)),
        actions: [
          TextButton(
            child: Text(L10().cancel),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

/*
 * Display a "confirmation" dialog allowing the user to accept or reject an action
 */
Future<void> confirmationDialog(
  String title,
  String text, {
  Color? color,
  IconData icon = TablerIcons.help_circle,
  String? acceptText,
  String? rejectText,
  Function? onAccept,
  Function? onReject,
}) async {
  String _accept = acceptText ?? L10().ok;
  String _reject = rejectText ?? L10().cancel;

  if (!hasContext()) {
    return;
  }

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
        iconColor: color,
        title: ListTile(
          title: Text(title, style: TextStyle(color: color)),
          leading: Icon(icon, color: color),
        ),
        content: text.isNotEmpty ? Text(text) : null,
        actions: [
          TextButton(
            child: Text(_reject),
            onPressed: () {
              // Close this dialog
              Navigator.pop(context);

              if (onReject != null) {
                onReject();
              }
            },
          ),
          TextButton(
            child: Text(_accept),
            onPressed: () {
              // Close this dialog
              Navigator.pop(context);

              if (onAccept != null) {
                onAccept();
              }
            },
          ),
        ],
      );
    },
  );
}

/*
 * Convert a raw API field name (snake_case) into a human-readable label,
 * e.g. "target_date" -> "Target Date"
 */
String _humanizeFieldName(String field) {
  return field
      .split("_")
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(" ");
}

/*
 * Build the body content for an error dialog, given either a plain
 * description string or a structured APIResponse.
 */
Widget _buildErrorContent(String description, APIResponse? response) {
  List<Widget> children = [];

  if (description.isNotEmpty) {
    children.add(Text(description));
  } else if (response != null) {
    final Map<String, dynamic> data = response.isMap() ? response.asMap() : {};

    if (data["detail"] is String) {
      // Standard DRF shape for auth / permission / not-found / throttle errors
      children.add(Text(data["detail"] as String));
    } else {
      // Non-field errors (form-level validation failures)
      List<String> nonFieldErrors = [];
      for (String key in ["detail", "non_field_errors", "__all__", "errors"]) {
        dynamic value = data[key];
        if (value is String) {
          nonFieldErrors.add(value);
        } else if (value is List) {
          nonFieldErrors.addAll(value.map((e) => e.toString()));
        }
      }

      for (String error in nonFieldErrors) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(error),
          ),
        );
      }

      // Per-field validation errors (typically a 400 response)
      if (response.statusCode == 400 && response.data is Map<String, dynamic>) {
        for (String field in data.keys) {
          if ([
            "detail",
            "non_field_errors",
            "__all__",
            "errors",
          ].contains(field)) {
            continue;
          }

          dynamic error = data[field];
          List<String> messages = error is List
              ? error.map((e) => e.toString()).toList()
              : [error.toString()];

          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _humanizeFieldName(field),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (String message in messages) Text(message),
                ],
              ),
            ),
          );
        }
      }

      // Nothing recognized above - fall back to a labeled raw diagnostic dump
      if (children.isEmpty) {
        children.add(Text(statusCodeToString(response.statusCode)));
        children.add(const SizedBox(height: 8));
        children.add(
          Text(
            L10().responseData,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
        children.add(
          Text(
            response.data.toString(),
            style: const TextStyle(fontFamily: "monospace", fontSize: 12),
          ),
        );
      }
    }
  }

  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 400),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

// Track whether an error dialog is currently being displayed,
// so that we do not stack multiple error dialogs on top of each other
// (e.g. when several API requests fail in quick succession on startup)
bool _errorDialogVisible = false;

/*
 * Construct an error dialog showing information to the user
 *
 * @title = Title to be displayed at the top of the dialog
 * @description = Simple string description of error
 * @response = Error response (e.g from server)
 */
Future<void> showErrorDialog(
  String title, {
  String description = "",
  APIResponse? response,
  IconData icon = TablerIcons.exclamation_circle,
  Color? color,
  Function? onDismissed,
}) async {
  if (!hasContext()) {
    return;
  }

  // Do not show a new error dialog if one is already visible
  if (_errorDialogVisible) {
    return;
  }

  _errorDialogVisible = true;

  final Color dialogColor = color ?? COLOR_DANGER;

  OneContext()
      .showDialog(
        builder: (context) => AlertDialog(
          icon: Icon(icon, color: dialogColor),
          iconColor: dialogColor,
          title: Text(title),
          content: _buildErrorContent(description, response),
          actions: [
            TextButton(
              child: Text(L10().ok),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      )
      .then((value) {
        _errorDialogVisible = false;
        if (onDismissed != null) {
          onDismissed();
        }
      });
}

/*
 * Display a message indicating the nature of a server / API error
 */
Future<void> showServerError(
  String url,
  String title,
  String description,
) async {
  if (!hasContext()) {
    return;
  }

  // We ignore error messages for certain URLs
  if (url.contains("notifications")) {
    return;
  }

  if (title.isEmpty) {
    title = L10().serverError;
  }

  // Play a sound
  final bool tones =
      await InvenTreeSettingsManager().getValue(INV_SOUNDS_SERVER, true)
          as bool;

  if (tones) {
    playAudioFile("sounds/server_error.mp3");
  }

  description += "\nURL: $url";

  showErrorDialog(title, description: description, icon: TablerIcons.server);
}

/*
 * Displays an error indicating that the server returned an unexpected status code
 */
Future<void> showStatusCodeError(
  String url,
  int status, {
  dynamic details,
}) async {
  String msg = statusCodeToString(status);
  String extra = url + "\n" + "${L10().statusCode}: ${status}";

  String errorDetails = extractErrorDetails(details);

  if (errorDetails.isNotEmpty) {
    extra += "\n";
    extra += errorDetails;
  }

  showServerError(url, msg, extra);
}

/*
 * Attempt to extract a human-readable error message from API response data.
 * The server commonly returns error information under a "detail", "error"
 * or "errors" key - prefer displaying that over the raw JSON.
 * Falls back to displaying the raw data as a list of key : value pairs.
 */
String extractErrorDetails(dynamic data) {
  if (data is Map) {
    for (final key in ["detail", "error", "errors"]) {
      var value = data[key];

      if (value == null) {
        continue;
      }

      if (value is List) {
        return value.map((e) => e.toString()).join("\n");
      }

      return value.toString();
    }

    if (data.isNotEmpty) {
      return data.entries.map((e) => "${e.key}: ${e.value}").join("\n");
    }

    return "";
  }

  if (data is List && data.isNotEmpty) {
    return data.map((e) => e.toString()).join("\n");
  }

  if (data is String) {
    return data;
  }

  return "";
}

/*
 * Provide a human-readable descriptor for a particular error code
 */
String statusCodeToString(int status) {
  switch (status) {
    case 400:
      return L10().response400;
    case 401:
      return L10().response401;
    case 403:
      return L10().response403;
    case 404:
      return L10().response404;
    case 405:
      return L10().response405;
    case 429:
      return L10().response429;
    case 500:
      return L10().response500;
    case 501:
      return L10().response501;
    case 502:
      return L10().response502;
    case 503:
      return L10().response503;
    case 504:
      return L10().response504;
    case 505:
      return L10().response505;
    default:
      return L10().responseInvalid + " : ${status}";
  }
}

/*
 * Displays a message indicating that the server timed out on a certain request
 */
Future<void> showTimeoutError(String url) async {
  await showServerError(url, L10().timeout, L10().noResponse);
}
