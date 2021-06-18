
import 'package:InvenTree/app_settings.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:InvenTree/l10.dart';
import 'package:one_context/one_context.dart';

Future<void> confirmationDialog(String title, String text, {String acceptText, String rejectText, Function onAccept, Function onReject}) async {

  if (acceptText == null || acceptText.isEmpty) {
    acceptText = L10().ok;
  }

  if (rejectText == null || rejectText.isEmpty) {
    rejectText = L10().cancel;
  }

  OneContext().showDialog(
    builder: (BuildContext context) {
      return AlertDialog(
        title: ListTile(
          title: Text(title),
          leading: FaIcon(FontAwesomeIcons.questionCircle),
        ),
        content: Text(text),
        actions: [
          FlatButton(
            child: Text(rejectText),
            onPressed: () {
              // Close this dialog
              Navigator.pop(context);

              if (onReject != null) {
                onReject();
              }
            }
          ),
          FlatButton(
            child: Text(acceptText),
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


Future<void> showInfoDialog(BuildContext context, String title, String description, {IconData icon = FontAwesomeIcons.info, String info, Function onDismissed}) async {

  if (info == null || info.isEmpty) {
    info = L10().info;
  }

  showDialog(
    context: context,
    builder: (BuildContext context) => SimpleDialog(
      title: ListTile(
        title: Text(info),
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

Future<void> showErrorDialog(String title, String description, {IconData icon = FontAwesomeIcons.exclamationCircle, String error, Function onDismissed}) async {

  if (error == null || error.isEmpty) {
    error = L10().error;
  }

  OneContext().showDialog(
    builder: (context) => SimpleDialog(
      title: ListTile(
        title: Text(error),
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

  if (title == null || title.isEmpty) {
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

Future<void> showStatusCodeError(int status, {int expected = 200}) async {

  BuildContext ctx = OneContext().context;

  String msg = L10().responseInvalid;
  String extra = "Server responded with status code ${status}";

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
    default:
      break;
  }

  showServerError(
    msg,
    extra,
  );
}

Future<void> showTimeoutError(BuildContext context) async {

  // Use OneContext as "sometimes" context is null here?
  var ctx = OneContext().context;

  await showServerError(L10().timeout, L10().noResponse);
}

void showFormDialog(String title, {String acceptText, String cancelText, GlobalKey<FormState> key, List<Widget> fields, List<Widget> actions, Function callback}) {

  BuildContext dialogContext;

  var ctx = OneContext().context;

  if (acceptText == null) {
    acceptText = L10().save;
  }

  if (cancelText == null) {
    cancelText = L10().cancel;
  }

  // Undefined actions = OK + Cancel
  if (actions == null) {
    actions = <Widget>[
      FlatButton(
        child: Text(cancelText),
        onPressed: () {
          // Close the form
          Navigator.pop(dialogContext);
        }
      ),
      FlatButton(
        child: Text(acceptText),
        onPressed: () {
          if (key.currentState.validate()) {
            key.currentState.save();

            // Close the dialog
            Navigator.pop(dialogContext);

            // Callback
            if (callback != null) {
              callback();
            }
          }
        }
      )
    ];
  }

  OneContext().showDialog(
    builder: (BuildContext context) {
      dialogContext = context;
      return AlertDialog(
          title: Text(title),
          actions: actions,
          content: Form(
              key: key,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fields
                  )
              )
          )
      );
    }
  );
}