import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'preferences.dart';

class InvenTreeLoginSettingsWidget extends StatefulWidget {

  @override
  _InvenTreeLoginSettingsState createState() => _InvenTreeLoginSettingsState();
}


class _InvenTreeLoginSettingsState extends State<InvenTreeLoginSettingsWidget> {

  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  String _addr;
  String _user;
  String _pass;

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
  void initState() {
    load();
  }

  @override
  Widget build(BuildContext context) {

    final Size screenSize = MediaQuery.of(context).size;

    load();

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
              Text("Server"),
              new TextFormField(
                initialValue: _addr,
                decoration: InputDecoration(
                  hintText: "127.0.0.1:8000",
                  labelText: "Server:Port",
                ),
                validator: _validateServer,
                onSaved: (String value) {
                  _addr = value;
                },
              ),
              Text("Login Details"),
              TextFormField(
                initialValue: _user,
                decoration: InputDecoration(
                  hintText: "Username",
                  labelText: "Username",
                ),
                validator: _validateUsername,
                onSaved: (String value) {
                  _user = value;
                }
              ),
              TextFormField(
                initialValue: _pass,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Password",
                  labelText: "Password",
                ),
                validator: _validatePassword,
                onSaved: (String value) {
                  _pass = value;
                },
              ),
              Container(
                width: screenSize.width,
                child: RaisedButton(
                  child: Text("Login"),
                  onPressed: this.save,
                )
              )
            ],
          )
        )
      )
    );
  }

  void load() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    _addr = prefs.getString('server');
    _user = prefs.getString('username');
    _pass = prefs.getString('password');

    // Refresh the widget
    setState(() {
    });
  }

  void save() async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();

      await InvenTreeUserPreferences().saveLoginDetails(_addr, _user, _pass);

    }
  }
}