import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
              Text("Server Address"),
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
                  hintText: "Username",
                  labelText: "Username",
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
                  hintText: "Password",
                  labelText: "Password",
                ),
                validator: _validatePassword,
                onSaved: (String value) {
                  _password = value;
                },
              ),
              Container(
                width: screenSize.width,
                child: RaisedButton(
                  child: Text("Save"),
                  onPressed: this.save,
                )
              )
            ],
          )
        )
      )
    );
  }

  void save() async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();

      await InvenTreePreferences().saveLoginDetails(_server, _username, _password);

    }
  }
}