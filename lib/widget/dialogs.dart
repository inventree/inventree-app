
import 'package:InvenTree/widget/snacks.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:one_context/one_context.dart';

Future<void> confirmationDialog(String title, String text, {String acceptText, String rejectText, Function onAccept, Function onReject}) async {

  if (acceptText == null || acceptText.isEmpty) {
    acceptText = I18N.of(OneContext().context).ok;
  }

  if (rejectText == null || rejectText.isEmpty) {
    rejectText = I18N.of(OneContext().context).cancel;
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

Future<void> showErrorDialog(String title, String description, {IconData icon = FontAwesomeIcons.exclamationCircle, String error, Function onDismissed}) async {

  if (error == null || error.isEmpty) {
    error = I18N.of(OneContext().context).error;
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
    title = I18N.of(OneContext().context).serverError;
  }

  showSnackIcon(
    title,
    success: false,
    actionText: I18N.of(OneContext().context).details,
    onAction: () {
      showErrorDialog(
          title,
          description,
          error: I18N.of(OneContext().context).serverError,
          icon: FontAwesomeIcons.server
      );
    }
  );
}

Future<void> showStatusCodeError(int status, {int expected = 200}) async {

  showServerError(
    I18N.of(OneContext().context).responseInvalid,
    "Server responded with status code ${status}"
  );
}

Future<void> showTimeoutError(BuildContext context) async {

  await showServerError(I18N.of(context).timeout, I18N.of(context).noResponse);
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

          print("cancel and close the dialog");
          // Close the form
          Navigator.pop(dialogContext);
        }
      ),
      FlatButton(
        child: Text(I18N.of(OneContext().context).save),
        onPressed: () {
          if (key.currentState.validate()) {
            key.currentState.save();

            print("Saving and closing the dialog");

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