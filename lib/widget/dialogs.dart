import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:one_context/one_context.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/preferences.dart";
import "package:inventree/widget/snacks.dart";


/*
 * Launch a dialog allowing the user to select from a list of options
 */
Future<void> choiceDialog(String title, List<Widget> items, {Function? onSelected}) async {

  List<Widget> choices = [];

  for (int idx = 0; idx < items.length; idx++) {
    choices.add(
      GestureDetector(
        child: items[idx],
        onTap: () {
          Navigator.pop(OneContext().context!);
          if (onSelected != null) {
            onSelected(idx);
          }
        },
      )
    );
  }

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            children: choices,
          )
        ),
        actions: [
          TextButton(
            child: Text(L10().cancel),
            onPressed: () {
              Navigator.pop(OneContext().context!);
            },
          )
        ],
      );
    }
  );

}


/*
 * Display a "confirmation" dialog allowing the user to accept or reject an action
 */
Future<void> confirmationDialog(String title, String text, {Color? color, IconData icon = FontAwesomeIcons.circleQuestion, String? acceptText, String? rejectText, Function? onAccept, Function? onReject}) async {

  String _accept = acceptText ?? L10().ok;
  String _reject = rejectText ?? L10().cancel;

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
        iconColor: color,
        title: ListTile(
          title: Text(title, style: TextStyle(color: color)),
          leading: FaIcon(icon, color: color),
        ),
        content: text.isEmpty ? Text(text) : null,
        actions: [
          TextButton(
            child: Text(_reject),
            onPressed: () {
              // Close this dialog
              Navigator.pop(context);

              if (onReject != null) {
                onReject();
              }
            }
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
          )
        ]
      );
    }
  );
}


/*
 * Construct an error dialog showing information to the user
 *
 * @title = Title to be displayed at the top of the dialog
 * @description = Simple string description of error
 * @data = Error response (e.g from server)
 */
Future<void> showErrorDialog(String title, {String description = "", APIResponse? response, IconData icon = FontAwesomeIcons.circleExclamation, Function? onDismissed}) async {

  List<Widget> children = [];

  if (description.isNotEmpty) {
    children.add(
      ListTile(
        title: Text(description),
      )
    );
  } else if (response != null) {
    // Look for extra error information in the provided APIResponse object
    switch (response.statusCode) {
      case 400:  // Bad request (typically bad input)
        if (response.data is Map<String, dynamic>) {

          for (String field in response.asMap().keys) {

            dynamic error = response.data[field];

            if (error is List) {
              for (int ii = 0; ii < error.length; ii++) {
                children.add(
                  ListTile(
                    title: Text(field),
                    subtitle: Text(error[ii].toString()),
                  )
                );
              }
            } else {
              children.add(
                  ListTile(
                    title: Text(field),
                    subtitle: Text(response.data[field].toString()),
                  )
              );
            }
          }
        } else {
          children.add(
            ListTile(
              title: Text(L10().responseInvalid),
              subtitle: Text(response.data.toString())
            )
          );
        }
        break;
      default:
        // Unhandled server response
        children.add(
          ListTile(
            title: Text(L10().statusCode),
            subtitle: Text(response.statusCode.toString()),
          )
        );

        children.add(
          ListTile(
            title: Text(L10().responseData),
            subtitle: Text(response.data.toString()),
          )
        );

        break;
    }
  }

  OneContext().showDialog(
    builder: (context) => SimpleDialog(
      title: ListTile(
        title: Text(title),
        leading: FaIcon(icon),
      ),
      children: children
    )
  ).then((value) {
    if (onDismissed != null) {
      onDismissed();
    }
  });
}

/*
 * Display a message indicating the nature of a server / API error
 */
Future<void> showServerError(String url, String title, String description) async {

  if (!OneContext.hasContext) {
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
  final bool tones = await InvenTreeSettingsManager().getValue(INV_SOUNDS_SERVER, true) as bool;

  if (tones) {
    playAudioFile("sounds/server_error.mp3");
  }

  showSnackIcon(
    title,
    success: false,
    actionText: L10().details,
    onAction: () {
      showErrorDialog(
          L10().serverError,
          description: description,
          icon: FontAwesomeIcons.server
      );
    }
  );
}

/*
 * Displays an error indicating that the server returned an unexpected status code
 */
Future<void> showStatusCodeError(String url, int status, {String details=""}) async {

  String msg = statusCodeToString(status);
  String extra = url + "\n" + "${L10().statusCode}: ${status}";

  if (details.isNotEmpty) {
    extra += "\n";
    extra += details;
  }

  showServerError(
    url,
    msg,
    extra,
  );
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
