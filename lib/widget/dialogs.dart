
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:one_context/one_context.dart';

Future<void> confirmationDialog(BuildContext context, String title, String text, {String acceptText, String rejectText, Function onAccept, Function onReject}) async {

  if (acceptText == null || acceptText.isEmpty) {
    acceptText = I18N.of(context).ok;
  }

  if (rejectText == null || rejectText.isEmpty) {
    rejectText = I18N.of(context).cancel;
  }

  AlertDialog dialog = AlertDialog(
    title: ListTile(
      title: Text(title),
      leading: FaIcon(FontAwesomeIcons.questionCircle),
    ),
    content: Text(text),
    actions: [
      FlatButton(
        child: Text(rejectText),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          if (onReject != null) {
            onReject();
          }
        }
      ),
      FlatButton(
        child: Text(acceptText),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          if (onAccept != null) {
            onAccept();
          }
        }
      )
    ],
  );

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return dialog;
    }
  );
}

void showMessage(BuildContext context, String message) {
  Scaffold.of(context).showSnackBar(SnackBar(
    content: Text(message),
  ));
}


Future<void> showInfoDialog(BuildContext context, String title, String description, {IconData icon = FontAwesomeIcons.info, String info, Function onDismissed}) async {

  if (info == null || info.isEmpty) {
    info = I18N.of(context).info;
  }

  showDialog(
    context: context,
    child: SimpleDialog(
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

Future<void> showErrorDialog(BuildContext context, String title, String description, {IconData icon = FontAwesomeIcons.exclamationCircle, String error, Function onDismissed}) async {

  if (error == null || error.isEmpty) {
    error = I18N.of(context).error;
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
          title: ListTile(
            title: Text(error),
            leading: FaIcon(icon),
          ),
          children: <Widget>[
            ListTile(
                title: Text(title),
                subtitle: Text(description)
            )
          ]
      );
    }).then((value) {
      if (onDismissed != null) {
        onDismissed();
      }
    });
}

Future<void> showServerError(BuildContext context, String title, String description) async {

  if (title == null || title.isEmpty) {
    title = I18N.of(context).serverError;
  }

  await showErrorDialog(
      context,
      title,
      description,
      error: I18N.of(context).serverError,
      icon: FontAwesomeIcons.server
  );
}

Future<void> showStatusCodeError(BuildContext context, int status, {int expected = 200}) async {

  await showServerError(
    context,
    "Invalid Response Code",
    "Server responded with status code ${status}"
  );
}

Future<void> showTimeoutError(BuildContext context) async {

  await showServerError(context, I18N.of(context).timeout, I18N.of(context).noResponse);
}

void showProgressDialog(BuildContext context, String title, String description) {

  showDialog(
    context: context,
    barrierDismissible: false,
    child: SimpleDialog(
      title: Text(title),
      children: <Widget>[
        CircularProgressIndicator(),
        Text(description),
      ],
    )
  );
}

void hideProgressDialog(BuildContext context) {
  Navigator.pop(context);
}

void showFormDialog(String title, {GlobalKey<FormState> key, List<Widget> fields, List<Widget> actions, Function callback}) {

  BuildContext dialogContext;

  // Undefined actions = OK + Cancel
  if (actions == null) {
    actions = <Widget>[
      FlatButton(
        child: Text(I18N.of(OneContext().context).cancel),
        onPressed: () {
          // Close the form
          Navigator.of(OneContext().context).pop();
        }
      ),
      FlatButton(
        child: Text(I18N.of(OneContext().context).save),
        onPressed: () {
          if (key.currentState.validate()) {
            key.currentState.save();

            // Close the dialog
            Navigator.pop(OneContext().context);

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