import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/settings/login_mfa.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/progress.dart";

/*
 * Act on the result of an authentication step (login, MFA, etc).
 * Shared between the login and MFA screens.
 *
 * - Authenticated: connect to the server and return to the home screen
 * - MFA required: open the MFA screen
 * - Otherwise: report the error via [onError]
 */
Future<void> handleAuthResult(
  BuildContext context,
  UserProfile profile,
  AuthResult result,
  void Function(String) onError,
) async {
  switch (result.status) {
    case AuthStatus.authenticated:
      // Connect using the new session, then return directly to the home screen
      await InvenTreeAPI().connectToServer(profile);

      hideLoadingOverlay();

      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    case AuthStatus.flowPending:
      hideLoadingOverlay();

      final AuthFlow flow = result.pendingFlow!;

      if (flow.isSupportedMfa) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InvenTreeMfaWidget(profile, flow),
            ),
          );
        }
      } else if (flow.id == FLOW_MFA_AUTHENTICATE) {
        onError(L10().mfaUnsupported);
      } else {
        onError("${L10().authFlowUnsupported} (${flow.id})");
      }
    case AuthStatus.failed:
      hideLoadingOverlay();

      String err = result.errorMessage;

      if (err.isEmpty && result.statusCode >= 0) {
        err = statusCodeToString(result.statusCode);
      }

      onError(err);
  }
}

class InvenTreeLoginWidget extends StatefulWidget {
  const InvenTreeLoginWidget(this.profile) : super();

  final UserProfile profile;

  @override
  _InvenTreeLoginState createState() => _InvenTreeLoginState();
}

class _InvenTreeLoginState extends State<InvenTreeLoginWidget> {
  final formKey = GlobalKey<FormState>();

  String username = "";
  String password = "";

  bool _obscured = true;

  String error = "";

  // Attempt login
  Future<void> _doLogin(BuildContext context) async {
    // Save form
    formKey.currentState?.save();

    bool valid = formKey.currentState?.validate() ?? false;

    if (valid) {
      // Dismiss the keyboard
      FocusScopeNode currentFocus = FocusScope.of(context);

      if (!currentFocus.hasPrimaryFocus) {
        currentFocus.unfocus();
      }

      showLoadingOverlay();

      setState(() {
        error = "";
      });

      final AuthResult result = await InvenTreeAuth().beginLogin(
        widget.profile,
        PasswordAuthMethod(username, password),
      );

      if (!context.mounted) {
        hideLoadingOverlay();
        return;
      }

      await handleAuthResult(context, widget.profile, result, (String err) {
        if (mounted) {
          setState(() {
            error = err;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> before = [
      ListTile(
        title: Text(L10().loginEnter),
        subtitle: Text(L10().loginEnterDetails),
        leading: Icon(TablerIcons.user_check),
      ),
      ListTile(
        title: Text(L10().server),
        subtitle: Text(widget.profile.server),
        leading: Icon(TablerIcons.server),
      ),
      if (Uri.tryParse(widget.profile.server)?.scheme == "http")
        ListTile(
          title: Text(
            L10().insecureConnection,
            style: TextStyle(color: COLOR_WARNING),
          ),
          subtitle: Text(L10().insecureConnectionDetail),
          leading: Icon(TablerIcons.lock_open, color: COLOR_WARNING),
        ),
      Divider(),
    ];

    List<Widget> after = [];

    if (error.isNotEmpty) {
      after.add(Divider());
      after.add(
        ListTile(
          leading: Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER),
          title: Text(L10().error, style: TextStyle(color: COLOR_DANGER)),
          subtitle: Text(error, style: TextStyle(color: COLOR_DANGER)),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().login),
        actions: [
          IconButton(
            icon: Icon(TablerIcons.transition_right, color: COLOR_SUCCESS),
            onPressed: () async {
              _doLogin(context);
            },
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...before,
              TextFormField(
                decoration: InputDecoration(
                  labelText: L10().username,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  hintText: L10().enterUsername,
                ),
                initialValue: widget.profile.username,
                autofocus: widget.profile.username.isEmpty,
                autocorrect: false,
                keyboardType: TextInputType.text,
                autofillHints: [AutofillHints.username],
                onSaved: (value) {
                  username = value?.trim() ?? "";
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return L10().usernameEmpty;
                  }

                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: L10().password,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  hintText: L10().enterPassword,
                  suffixIcon: IconButton(
                    icon: _obscured
                        ? Icon(TablerIcons.eye)
                        : Icon(TablerIcons.eye_off),
                    onPressed: () {
                      setState(() {
                        _obscured = !_obscured;
                      });
                    },
                  ),
                ),
                initialValue: "",
                autofocus: widget.profile.username.isNotEmpty,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: [AutofillHints.password],
                obscureText: _obscured,
                onSaved: (value) {
                  // Do not trim - whitespace is a valid password character
                  password = value ?? "";
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return L10().passwordEmpty;
                  }

                  return null;
                },
              ),
              ...after,
            ],
          ),
          padding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}
