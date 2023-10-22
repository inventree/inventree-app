import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/settings/login.dart";
import "package:one_context/one_context.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/spinner.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/user_profile.dart";

class InvenTreeSelectServerWidget extends StatefulWidget {

  @override
  _InvenTreeSelectServerState createState() => _InvenTreeSelectServerState();
}


class _InvenTreeSelectServerState extends State<InvenTreeSelectServerWidget> {

  _InvenTreeSelectServerState() {
    _reload();
  }

  final GlobalKey<_InvenTreeSelectServerState> _loginKey = GlobalKey<_InvenTreeSelectServerState>();

  List<UserProfile> profiles = [];

  Future <void> _reload() async {

    profiles = await UserProfileDBManager().getAllProfiles();

    if (!mounted) {
      return;
    }

    setState(() {
    });
  }

  /*
   * Logout the selected profile (delete the stored token)
   */
  Future<void> _logoutProfile(BuildContext context, {UserProfile? userProfile}) async {

    if (userProfile != null) {
      userProfile.token = "";
      await UserProfileDBManager().updateProfile(userProfile);

      _reload();
    }

    InvenTreeAPI().disconnectFromServer();
    _reload();

  }

  /*
   * Edit the selected profile
   */
  void _editProfile(BuildContext context, {UserProfile? userProfile, bool createNew = false}) {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditWidget(userProfile)
      )
    ).then((context) {
      _reload();
    });
  }

  Future <void> _selectProfile(BuildContext context, UserProfile profile) async {

    // Disconnect InvenTree
    InvenTreeAPI().disconnectFromServer();

    var key = profile.key;

    if (key == null) {
      return;
    }

    await UserProfileDBManager().selectProfile(key);

    UserProfile? prf = await UserProfileDBManager().getProfileByKey(key);

    if (prf == null) {
      return;
    }

    // First check if the profile has an associate token
    if (!prf.hasToken) {
      // Redirect user to login screen
      Navigator.push(context,
        MaterialPageRoute(builder: (context) => InvenTreeLoginWidget(profile))
      ).then((value) async {
        _reload();
        // Reload profile
        prf = await UserProfileDBManager().getProfileByKey(key);
        if (prf?.hasToken ?? false) {
          InvenTreeAPI().connectToServer(prf!).then((result) {
            _reload();
          });
        }
      });

      // Exit now, login handled by next widget
      return;
    }

    if (!mounted) {
      return;
    }

    _reload();

    // Attempt server login (this will load the newly selected profile
    InvenTreeAPI().connectToServer(prf).then((result) {
      _reload();
    });

    _reload();
  }

  Future <void> _deleteProfile(UserProfile profile) async {

    await UserProfileDBManager().deleteProfile(profile);

    if (!mounted) {
      return;
    }

    _reload();

    if (InvenTreeAPI().isConnected() && profile.key == (InvenTreeAPI().profile?.key ?? "")) {
      InvenTreeAPI().disconnectFromServer();
    }
  }

  Widget? _getProfileIcon(UserProfile profile) {

    // Not selected? No icon for you!
    if (!profile.selected) return null;

    // Selected, but (for some reason) not the same as the API...
    if ((InvenTreeAPI().profile?.key ?? "") != profile.key) {
      return null;
    }

    // Reflect the connection status of the server
    if (InvenTreeAPI().isConnected()) {
      return FaIcon(
        FontAwesomeIcons.circleCheck,
        color: COLOR_SUCCESS
      );
    } else if (InvenTreeAPI().isConnecting()) {
      return Spinner(
        icon: FontAwesomeIcons.spinner,
        color: COLOR_PROGRESS,
      );
    } else {
      return FaIcon(
        FontAwesomeIcons.circleXmark,
        color: COLOR_DANGER,
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    List<Widget> children = [];

    if (profiles.isNotEmpty) {
      for (int idx = 0; idx < profiles.length; idx++) {
        UserProfile profile = profiles[idx];

        children.add(ListTile(
          title: Text(
            profile.name,
          ),
          tileColor: profile.selected ? Theme.of(context).secondaryHeaderColor : null,
          subtitle: Text("${profile.server}"),
          leading: profile.hasToken ? FaIcon(FontAwesomeIcons.userCheck, color: COLOR_SUCCESS) : FaIcon(FontAwesomeIcons.userSlash, color: COLOR_WARNING),
          trailing: _getProfileIcon(profile),
          onTap: () {
            _selectProfile(context, profile);
          },
          onLongPress: () {
            OneContext().showDialog(
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: Text(profile.name),
                    children: <Widget>[
                      Divider(),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _selectProfile(context, profile);
                        },
                        child: ListTile(
                          title: Text(L10().profileConnect),
                          leading: FaIcon(FontAwesomeIcons.server),
                        )
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _editProfile(context, userProfile: profile);
                        },
                        child: ListTile(
                          title: Text(L10().profileEdit),
                          leading: FaIcon(FontAwesomeIcons.penToSquare)
                        )
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _logoutProfile(context, userProfile: profile);
                        },
                        child: ListTile(
                          title: Text(L10().profileLogout),
                          leading: FaIcon(FontAwesomeIcons.userSlash),
                        )
                      ),
                      Divider(),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigator.of(context, rootNavigator: true).pop();
                          confirmationDialog(
                            L10().delete,
                            L10().profileDelete + "?",
                            color: Colors.red,
                            icon: FontAwesomeIcons.trashCan,
                            onAccept: () {
                              _deleteProfile(profile);
                            }
                          );
                        },
                        child: ListTile(
                          title: Text(L10().profileDelete, style: TextStyle(color: Colors.red)),
                          leading: FaIcon(FontAwesomeIcons.trashCan, color: Colors.red),
                        )
                      )
                    ],
                  );
                }
            );
          },
        ));
      }
    } else {
      // No profile available!
      children.add(
        ListTile(
          title: Text(L10().profileNone),
        )
      );
    }

    return Scaffold(
      key: _loginKey,
      appBar: AppBar(
        title: Text(L10().profileSelect),
        actions: [
          IconButton(
            icon: FaIcon(FontAwesomeIcons.circlePlus),
            onPressed: () {
              _editProfile(context, createNew: true);
            },
          )
        ],
      ),
      body: Container(
        child: ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: children
          ).toList(),
        )
      ),
    );
  }
}


/*
 * Widget for editing server details
 */
class ProfileEditWidget extends StatefulWidget {

  const ProfileEditWidget(this.profile) : super();

  final UserProfile? profile;

  @override
  _ProfileEditState createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEditWidget> {

  _ProfileEditState() : super();

  final formKey = GlobalKey<FormState>();

  String name = "";
  String server = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? L10().profileAdd : L10().profileEdit),
        actions: [
          IconButton(
            icon: FaIcon(FontAwesomeIcons.floppyDisk),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();

                UserProfile? prf = widget.profile;

                if (prf == null) {
                  UserProfile profile = UserProfile(
                    name: name,
                    server: server,
                  );

                  await UserProfileDBManager().addProfile(profile);
                } else {

                  prf.name = name;
                  prf.server = server;

                  await UserProfileDBManager().updateProfile(prf);
                }

                // Close the window
                Navigator.of(context).pop();
              }
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
              TextFormField(
                decoration: InputDecoration(
                  labelText: L10().profileName,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                initialValue: widget.profile?.name ?? "",
                maxLines: 1,
                keyboardType: TextInputType.text,
                onSaved: (value) {
                  name = value?.trim() ?? "";
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return L10().valueCannotBeEmpty;
                  }

                  return null;
                }
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: L10().server,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  hintText: "http[s]://<server>:<port>",
                ),
                initialValue: widget.profile?.server ?? "",
                keyboardType: TextInputType.url,
                onSaved: (value) {
                  server = value?.trim() ?? "";
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return L10().serverEmpty;
                  }

                  value = value.trim();

                  // Spaces are bad
                  if (value.contains(" ")) {
                    return L10().invalidHost;
                  }

                  if (!value.startsWith("http:") && !value.startsWith("https:")) {
                    // return L10().serverStart;
                  }

                  Uri? _uri = Uri.tryParse(value);

                  if (_uri == null || _uri.host.isEmpty) {
                    return L10().invalidHost;
                  } else {
                    Uri uri = Uri.parse(value);

                    if (uri.hasScheme) {
                      if (!["http", "https"].contains(uri.scheme.toLowerCase())) {
                        return L10().serverStart;
                      }
                    } else {
                      return L10().invalidHost;
                    }
                  }

                  // Everything is OK
                  return null;
                },
              ),
            ]
          ),
          padding: EdgeInsets.all(16),
        ),
      )
    );
  }

}