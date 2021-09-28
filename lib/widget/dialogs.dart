
import "package:inventree/app_settings.dart";
import "package:inventree/widget/snacks.dart";
import "package:audioplayers/audioplayers.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/l10.dart";
import "package:one_context/one_context.dart";

Future<void> confirmationDialog(String title, String text, {String? acceptText, String? rejectText, Function? onAccept, Function? onReject}) async {

  String _accept = acceptText ?? L10().ok;
  String _reject = rejectText ?? L10().cancel;

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
        title: ListTile(
          title: Text(title),
          leading: FaIcon(FontAwesomeIcons.questionCircle),
        ),
        content: Text(text),
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


Future<void> showInfoDialog(String title, String description, {IconData icon = FontAwesomeIcons.info, String? info, Function()? onDismissed}) async {

  String _info = info ?? L10().info;

  OneContext().showDialog(
    builder: (BuildContext context) => SimpleDialog(
      title: ListTile(
        title: Text(_info),
        leading: FaIcon(icon),
      ),
      children: <Widget>[
        ListTile(
          title: Text(title),
          subtitle: Text(description)
        )
      ]
    )
  ).then((value) {
    if (onDismissed != null) {
      onDismissed();
    }
  });
}

Future<void> showErrorDialog(String title, String description, {IconData icon = FontAwesomeIcons.exclamationCircle, String? error, Function? onDismissed}) async {

  String _error = error ?? L10().error;

  OneContext().showDialog(
    builder: (context) => SimpleDialog(
      title: ListTile(
        title: Text(_error),
        leading: FaIcon(icon),
      ),
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text(description),
        )
      ],
    )
  ).then((value) {
    if (onDismissed != null) {
      onDismissed();
    }
  });
}

Future<void> showServerError(String title, String description) async {

  if (title.isEmpty) {
    title = L10().serverError;
  }

  // Play a sound
  final bool tones = await InvenTreeSettingsManager().getValue("serverSounds", true) as bool;

  if (tones) {
    final player = AudioCache();
    player.play("sounds/server_error.mp3");
  }

  showSnackIcon(
    title,
    success: false,
    actionText: L10().details,
    onAction: () {
      showErrorDialog(
          title,
          description,
          error: L10().serverError,
          icon: FontAwesomeIcons.server
      );
    }
  );
}

Future<void> showStatusCodeError(int status) async {

  String msg = L10().responseInvalid;
  String extra = "${L10().statusCode}: ${status}";

  switch (status) {
    case 400:
      msg = L10().response400;
      break;
    case 401:
      msg = L10().response401;
      break;
    case 403:
      msg = L10().response403;
      break;
    case 404:
      msg = L10().response404;
      break;
    case 405:
      msg = L10().response405;
      break;
    case 429:
      msg = L10().response429;
      break;
    case 500:
      msg = L10().response500;
      break;
    case 501:
      msg = L10().response501;
      break;
    case 502:
      msg = L10().response502;
      break;
    case 503:
      msg = L10().response503;
      break;
    case 504:
      msg = L10().response504;
      break;
    case 505:
      msg = L10().response505;
      break;
    default:
      break;
  }

  showServerError(
    msg,
    extra,
  );
}

Future<void> showTimeoutError() async {
  await showServerError(L10().timeout, L10().noResponse);
}

void showFormDialog(String title, {String? acceptText, String? cancelText, GlobalKey<FormState>? key, List<Widget>? fields, Function? callback}) {


  String _accept = acceptText ?? L10().save;
  String _cancel = cancelText ?? L10().cancel;

  List<Widget> _fields = fields ?? [];

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
          title: Text(title),
          actions: <Widget>[
            TextButton(
                child: Text(_cancel),
                onPressed: () {
                  // Close the form
                  Navigator.pop(context);
                }
            ),
            TextButton(
                child: Text(_accept),
                onPressed: () {

                  var _key = key;

                  if (_key != null && _key.currentState != null) {
                    if (_key.currentState!.validate()) {
                      _key.currentState!.save();

                      Navigator.pop(context);

                      // Callback
                      if (callback != null) {
                        callback();
                      }
                    }
                  }
                }
            )
          ],
          content: Form(
              key: key,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _fields
                  )
              )
          )
      );
    }
  );
}