
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/progress.dart";


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

      showLoadingOverlay(context);

      // Attempt login
      final response = await InvenTreeAPI().fetchToken(widget.profile, username, password);

      hideLoadingOverlay();

      if (response.successful()) {
        // Return to the server selector screen
        Navigator.of(context).pop();
      } else {
        var data = response.asMap();

        String err;

        if (data.containsKey("detail")) {
          err = (data["detail"] ?? "") as String;
        } else {
          err = statusCodeToString(response.statusCode);
        }
        setState(() {
          error = err;
        });
      }
    }

  }

  @override
  Widget build(BuildContext context) {

    List<Widget> before = [
      ListTile(
        title: Text(L10().loginEnter),
        subtitle: Text(L10().loginEnterDetails),
        leading: FaIcon(FontAwesomeIcons.userCheck),
      ),
      ListTile(
        title: Text(L10().server),
        subtitle: Text(widget.profile.server),
        leading: FaIcon(FontAwesomeIcons.server),
      ),
      Divider(),
    ];

    List<Widget> after = [];

    if (error.isNotEmpty) {
      after.add(Divider());
      after.add(ListTile(
        leading: FaIcon(FontAwesomeIcons.circleExclamation, color: COLOR_DANGER),
        title: Text(L10().error, style: TextStyle(color: COLOR_DANGER)),
        subtitle: Text(error, style: TextStyle(color: COLOR_DANGER)),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().login),
        actions: [
          IconButton(
            icon: FaIcon(FontAwesomeIcons.arrowRightToBracket, color: COLOR_SUCCESS),
            onPressed: () async {
              _doLogin(context);
            },
          )
        ]
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
                    hintText: L10().enterUsername
                ),
                initialValue: "",
                keyboardType: TextInputType.text,
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
                      icon: _obscured ? FaIcon(FontAwesomeIcons.eye) : FaIcon(FontAwesomeIcons.solidEyeSlash),
                      onPressed: () {
                        setState(() {
                          _obscured = !_obscured;
                        });
                      },
                    ),
                  ),
                  initialValue: "",
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscured,
                  onSaved: (value) {
                    password = value?.trim() ?? "";
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return L10().passwordEmpty;
                    }

                    return null;
                  }
              ),
              ...after,
            ],
          ),
          padding: EdgeInsets.all(16),
        )
      )
    );

  }

}