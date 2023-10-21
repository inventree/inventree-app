

import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";

/**
 * clas
 */

class InvenTreeLoginWidget extends StatefulWidget {

  InvenTreeLoginWidget(this.profile);

  UserProfile profile;

  @override
  _InvenTreeLoginState createState() => _InvenTreeLoginState();

}


class _InvenTreeLoginState extends State<InvenTreeLoginWidget> {

  final formKey = GlobalKey<FormState>();

  String username = "";
  String password = "";

  bool _obscured = true;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(L10().login),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    password = value ?? "";
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return L10().passwordEmpty;
                    }

                    return null;
                  }
              ),
              Spacer(),
              TextButton(
                child: Text(L10().login),
                onPressed: () {
                  // TODO: attempt login
                },
              )
            ],
          )
        )
      )
    );

  }

}