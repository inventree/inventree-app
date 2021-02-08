import 'dart:ffi';

import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../api.dart';
import '../preferences.dart';
import '../user_profile.dart';

class InvenTreeLoginSettingsWidget extends StatefulWidget {

  final SharedPreferences _preferences;

  final List<UserProfile> _profiles;

  InvenTreeLoginSettingsWidget(this._profiles, this._preferences) : super();

  @override
  _InvenTreeLoginSettingsState createState() => _InvenTreeLoginSettingsState(_profiles, _preferences);
}


class _InvenTreeLoginSettingsState extends State<InvenTreeLoginSettingsWidget> {

  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  final GlobalKey<FormState> _addProfileKey = new GlobalKey<FormState>();

  final SharedPreferences _preferences;

  List<UserProfile> profiles;

  String _server = '';
  String _username = '';
  String _password = '';

  _InvenTreeLoginSettingsState(this.profiles, this._preferences) : super() {
    _server = _preferences.getString('server') ?? '';
    _username = _preferences.getString('username') ?? '';
    _password = _preferences.getString('password') ?? '';
  }

  void _reload() async {

    profiles = await UserProfileDBManager().getAllProfiles();

    setState(() {
    });
  }

  void _createProfile(BuildContext context) {

    var _name;
    var _server;
    var _username;
    var _password;

    showFormDialog(
      context,
      I18N.of(context).profileAdd,
      key: _addProfileKey,
      actions: <Widget> [
        FlatButton(
          child: Text(I18N.of(context).cancel),
          onPressed: () {
            Navigator.of(context).pop();
          }
        ),
        FlatButton(
          child: Text(I18N.of(context).save),
          onPressed: () {
            if (_addProfileKey.currentState.validate()) {
              _addProfileKey.currentState.save();

              // TODO - create the new profile...
              UserProfile profile = UserProfile(
                name: _name,
                server: _server,
                username: _username,
                password: _password
              );

              _addProfile(profile);
            }
          }
        )
      ],
      fields: <Widget> [
        StringField(
          label: I18N.of(context).name,
          hint: "Enter profile name",
          onSaved: (value) => _name = value,
          validator: _validateProfileName,
        ),
        StringField(
          label: I18N.of(context).server,
          initial: "http://127.0.0.1:8000",
          hint: "http[s]://<server>:<port>",
          validator: _validateServer,
          onSaved: (value) => _server = value,
        ),
        StringField(
          label: I18N.of(context).username,
          hint: "Enter username",
          onSaved: (value) => _username = value,
          validator: _validateUsername,
        ),
        StringField(
          label: I18N.of(context).password,
          hint: "Enter password",
          onSaved: (value) => _password = value,
          validator: _validatePassword,
        )
      ]
    );
  }

  String _validateProfileName(String value) {

    if (value.isEmpty) {
      return 'Profile name cannot be empty';
    }

    // TODO: Check if a profile already exists with ths name

    return null;
  }

  String _validateServer(String value) {

    if (value.isEmpty) {
      return 'Server cannot be empty';
    }

    if (!value.startsWith("http:") && !value.startsWith("https:")) {
      return 'Server must start with http[s]';
    }

    // TODO: URL validator

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

      // TODO
      await InvenTreePreferences().saveLoginDetails(context, _server, _username, _password);

    }
  }

  void _selectProfile(UserProfile profile) async {

    // Mark currently selected profile as unselected
    final selected = await UserProfileDBManager().getSelectedProfile();

    selected.selected = false;

    await UserProfileDBManager().updateProfile(selected);

    profile.selected = true;

    await UserProfileDBManager().updateProfile(profile);

    _reload();
  }

  void _deleteProfile(UserProfile profile) async {

    await UserProfileDBManager().deleteProfile(profile);

    // Close the dialog
    Navigator.of(context).pop();

    _reload();
  }

  void _addProfile(UserProfile profile) async {

    await UserProfileDBManager().addProfile(profile);

    // Dismiss the create dialog
    Navigator.of(context).pop();

    _reload();
  }

  @override
  Widget build(BuildContext context) {

    final Size screenSize = MediaQuery.of(context).size;

    List<Widget> children = [];

    for (int idx = 0; idx < profiles.length; idx++) {

      UserProfile profile = profiles[idx];

      children.add(ListTile(
        title: Text(
            profile.name,
        ),
        subtitle: Text(profile.server),
        trailing: profile.selected ? FaIcon(FontAwesomeIcons.checkCircle) : null,
        onLongPress: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SimpleDialog(
                title: Text(profile.name),
                children: <Widget> [
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _selectProfile(profile);
                    },
                    child: Text(I18N.of(context).profileSelect),
                  ),
                  SimpleDialogOption(
                    onPressed: () {
                      //Navigator.of(context).pop();
                      // TODO - Edit profile!
                    },
                    child: Text(I18N.of(context).profileEdit),
                  ),
                  SimpleDialogOption(
                    onPressed: () {
                      // Navigator.of(context, rootNavigator: true).pop();
                      confirmationDialog(
                          context,
                          "Delete",
                          "Delete this profile?",
                          onAccept: () {
                            _deleteProfile(profile);
                          }
                      );
                    },
                    child: Text(I18N.of(context).profileDelete),
                  )
                ],
              );
            }
          );
        },
        onTap: () {

        },
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(I18N.of(context).profile),
      ),
      body: Container(
        child: ListView(
          children: children,
        )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(FontAwesomeIcons.plus),
        onPressed: () {
          _createProfile(context);
        },
      )
    );

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
              Text(I18N.of(context).accountDetails),
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