import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../api.dart';
import '../preferences.dart';
import '../user_profile.dart';

class InvenTreeLoginSettingsWidget extends StatefulWidget {

  final List<UserProfile> _profiles;

  InvenTreeLoginSettingsWidget(this._profiles) : super();

  @override
  _InvenTreeLoginSettingsState createState() => _InvenTreeLoginSettingsState(_profiles);
}


class _InvenTreeLoginSettingsState extends State<InvenTreeLoginSettingsWidget> {

  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  final GlobalKey<FormState> _addProfileKey = new GlobalKey<FormState>();

  List<UserProfile> profiles;

  _InvenTreeLoginSettingsState(this.profiles);

  void _reload() async {

    profiles = await UserProfileDBManager().getAllProfiles();

    setState(() {
    });
  }

  void _editProfile(BuildContext context, {UserProfile userProfile, bool createNew = false}) {

    var _name;
    var _server;
    var _username;
    var _password;

    UserProfile profile;

    if (userProfile != null) {
      profile = userProfile;
    }

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

              if (createNew) {
                // TODO - create the new profile...
                UserProfile profile = UserProfile(
                  name: _name,
                  server: _server,
                  username: _username,
                  password: _password
                );

                _addProfile(profile);
              } else {

                profile.name = _name;
                profile.server = _server;
                profile.username = _username;
                profile.password = _password;

                _updateProfile(profile);

              }
            }
          }
        )
      ],
      fields: <Widget> [
        StringField(
          label: I18N.of(context).name,
          hint: "Enter profile name",
          initial: createNew ? '' : profile.name,
          onSaved: (value) => _name = value,
          validator: _validateProfileName,
        ),
        StringField(
          label: I18N.of(context).server,
          hint: "http[s]://<server>:<port>",
          initial: createNew ? '' : profile.server,
          validator: _validateServer,
          onSaved: (value) => _server = value,
        ),
        StringField(
          label: I18N.of(context).username,
          hint: "Enter username",
          initial: createNew ? '' : profile.username,
          onSaved: (value) => _username = value,
          validator: _validateUsername,
        ),
        StringField(
          label: I18N.of(context).password,
          hint: "Enter password",
          initial: createNew ? '' : profile.password,
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

  void _updateProfile(UserProfile profile) async {

    await UserProfileDBManager().updateProfile(profile);

    // Dismiss the dialog
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
                      Navigator.of(context).pop();
                      _editProfile(context, userProfile: profile);
                    },
                    child: Text(I18N.of(context).profileEdit),
                  ),
                  SimpleDialogOption(
                    onPressed: () {
                      // Navigator.of(context, rootNavigator: true).pop();
                      confirmationDialog(
                          context,
                          I18N.of(context).delete,
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
        title: Text(I18N.of(context).profileSelect),
      ),
      body: Container(
        child: ListView(
          children: children,
        )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(FontAwesomeIcons.plus),
        onPressed: () {
          _editProfile(context, createNew: true);
        },
      )
    );
  }
}