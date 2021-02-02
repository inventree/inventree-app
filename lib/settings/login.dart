import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../api.dart';
import '../preferences.dart';

class InvenTreeLoginSettingsWidget extends StatefulWidget {

  final SharedPreferences _preferences;

  InvenTreeLoginSettingsWidget(this._preferences) : super();

  @override
  _InvenTreeLoginSettingsState createState() => _InvenTreeLoginSettingsState(_preferences);
}


class _InvenTreeLoginSettingsState extends State<InvenTreeLoginSettingsWidget> {

  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  final SharedPreferences _preferences;

  String _server = '';
  String _username = '';
  String _password = '';

  _InvenTreeLoginSettingsState(this._preferences) : super() {
    _server = _preferences.getString('server') ?? '';
    _username = _preferences.getString('username') ?? '';
    _password = _preferences.getString('password') ?? '';
  }


  String _validateServer(String value) {

    if (value.isEmpty) {
      return 'Server cannot be empty';
    }

    if (!value.startsWith("http:") && !value.startsWith("https:")) {
      return 'Server must start with http[s]';
    }

    return null;
  }

  String _validateUsername(String value) {
    if (value.isEmpty) {
      return 'Username cannot be empty';
    }

    return null;
  }

  String _validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password cannot be empty';
    }

    return null;
  }

  void _save(BuildContext context) async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();

      await InvenTreePreferences().saveLoginDetails(context, _server, _username, _password);

    }
  }

  @override
  Widget build(BuildContext context) {

    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text("Login Settings"),
      ),
      body: new Container(
        padding: new EdgeInsets.all(20.0),
        child: new Form(
          key: _formKey,
          child: new ListView(
            children: <Widget>[
              Text(I18N.of(context).serverAddress),
              new TextFormField(
                initialValue: _server,
                decoration: InputDecoration(
                  hintText: "127.0.0.1:8000",
                ),
                validator: _validateServer,
                onSaved: (String value) {
                  _server = value;
                },
              ),
              Divider(),
              Text("Account Details"),
              TextFormField(
                initialValue: _username,
                decoration: InputDecoration(
                  hintText: I18N.of(context).username,
                  labelText: I18N.of(context).username,
                ),
                validator: _validateUsername,
                onSaved: (String value) {
                  _username = value;
                }
              ),
              TextFormField(
                initialValue: _password,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: I18N.of(context).password,
                  labelText: I18N.of(context).password,
                ),
                validator: _validatePassword,
                onSaved: (String value) {
                  _password = value;
                },
              ),
              Container(
                width: screenSize.width,
                child: RaisedButton(
                  child: Text(I18N.of(context).save),
                  onPressed: () {
                    _save(context);
                  }
                )
              )
            ],
          )
        )
      )
    );
  }
}