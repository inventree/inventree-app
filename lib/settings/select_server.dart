import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:one_context/one_context.dart";

import "package:inventree/settings/login.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/widget/dialogs.dart";
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

  final GlobalKey<_InvenTreeSelectServerState> _loginKey =
      GlobalKey<_InvenTreeSelectServerState>();

  List<UserProfile> profiles = [];

  Future<void> _reload() async {
    profiles = await UserProfileDBManager().getAllProfiles();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  /*
   * Logout the selected profile (delete the stored token)
   */
  Future<void> _logoutProfile(
    BuildContext context, {
    UserProfile? userProfile,
  }) async {
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
  void _editProfile(
    BuildContext context, {
    UserProfile? userProfile,
    bool createNew = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileEditWidget(userProfile)),
    ).then((context) {
      _reload();
    });
  }

  /*
   * Select the given profile as "active".
   * If a *different* server is currently connected, confirm with the
   * user first, since this immediately tears down the active session.
   */
  Future<void> _selectProfile(BuildContext context, UserProfile profile) async {
    final bool switchingAwayFromActiveSession =
        InvenTreeAPI().isConnected() &&
        InvenTreeAPI().profile?.key != profile.key;

    if (switchingAwayFromActiveSession) {
      confirmationDialog(
        L10().profileConnect,
        L10().profileSwitchConfirm,
        icon: TablerIcons.server,
        onAccept: () {
          _doSelectProfile(context, profile);
        },
      );
    } else {
      _doSelectProfile(context, profile);
    }
  }

  Future<void> _doSelectProfile(
    BuildContext context,
    UserProfile profile,
  ) async {
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
      // Redirect user to the login screen - it connects on success itself
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InvenTreeLoginWidget(profile)),
      );

      _reload();
      return;
    }

    if (!mounted) {
      return;
    }

    // Attempt server connection using the existing token
    await InvenTreeAPI().connectToServer(prf);

    _reload();
  }

  Future<void> _deleteProfile(UserProfile profile) async {
    await UserProfileDBManager().deleteProfile(profile);

    if (!mounted) {
      return;
    }

    _reload();

    if (InvenTreeAPI().isConnected() &&
        profile.key == (InvenTreeAPI().profile?.key ?? "")) {
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
      return Icon(TablerIcons.circle_check, color: COLOR_SUCCESS);
    } else if (InvenTreeAPI().isConnecting()) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(color: COLOR_PROGRESS, strokeWidth: 2),
      );
    } else {
      return Icon(TablerIcons.circle_x, color: COLOR_DANGER);
    }
  }

  /*
   * Show the profile action menu (Connect / Edit / Logout / Delete).
   * Reachable via the always-visible trailing "more" button, or long-press
   * as a bonus shortcut.
   */
  void _showProfileActions(BuildContext context, UserProfile profile) {
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
                leading: Icon(TablerIcons.server),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _editProfile(context, userProfile: profile);
              },
              child: ListTile(
                title: Text(L10().profileEdit),
                leading: Icon(TablerIcons.edit),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _logoutProfile(context, userProfile: profile);
              },
              child: ListTile(
                title: Text(L10().profileLogout),
                leading: Icon(TablerIcons.logout),
              ),
            ),
            Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                confirmationDialog(
                  L10().delete,
                  L10().profileDelete + "?",
                  color: COLOR_DANGER,
                  icon: TablerIcons.trash,
                  onAccept: () {
                    _deleteProfile(profile);
                  },
                );
              },
              child: ListTile(
                title: Text(
                  L10().profileDelete,
                  style: TextStyle(color: COLOR_DANGER),
                ),
                leading: Icon(TablerIcons.trash, color: COLOR_DANGER),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    if (profiles.isNotEmpty) {
      for (int idx = 0; idx < profiles.length; idx++) {
        UserProfile profile = profiles[idx];

        children.add(
          ListTile(
            title: Text(profile.name),
            tileColor: profile.selected
                ? Theme.of(context).secondaryHeaderColor
                : null,
            subtitle: Text("${profile.server}"),
            leading: profile.hasToken
                ? Icon(TablerIcons.user_check, color: COLOR_SUCCESS)
                : Icon(TablerIcons.user_cancel, color: COLOR_WARNING),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_getProfileIcon(profile) != null) _getProfileIcon(profile)!,
                IconButton(
                  icon: Icon(Icons.more_vert),
                  tooltip: L10().actions,
                  onPressed: () {
                    _showProfileActions(context, profile);
                  },
                ),
              ],
            ),
            onTap: () {
              _selectProfile(context, profile);
            },
            onLongPress: () {
              _showProfileActions(context, profile);
            },
          ),
        );
      }
    } else {
      // No profile available!
      children.add(ListTile(title: Text(L10().profileNone)));
    }

    return Scaffold(
      key: _loginKey,
      appBar: AppBar(
        title: Text(L10().profileSelect),
        actions: [
          IconButton(
            icon: Icon(TablerIcons.circle_plus),
            onPressed: () {
              _editProfile(context, createNew: true);
            },
          ),
        ],
      ),
      body: Container(
        child: ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: children,
          ).toList(),
        ),
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

  bool? serverStatus;
  bool serverChecking = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.profile == null ? L10().profileAdd : L10().profileEdit,
        ),
        actions: [
          IconButton(
            icon: Icon(TablerIcons.circle_check),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();

                UserProfile? prf = widget.profile;

                if (prf == null) {
                  UserProfile profile = UserProfile(name: name, server: server);

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
                },
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

                  if (!value.startsWith("http:") &&
                      !value.startsWith("https:")) {
                    // return L10().serverStart;
                  }

                  Uri? _uri = Uri.tryParse(value);

                  if (_uri == null || _uri.host.isEmpty) {
                    return L10().invalidHost;
                  } else {
                    Uri uri = Uri.parse(value);

                    if (uri.hasScheme) {
                      if (![
                        "http",
                        "https",
                      ].contains(uri.scheme.toLowerCase())) {
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
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  L10().connectionCheckDetail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  label: Text(L10().connectionCheck),
                  icon: serverStatus == true
                      ? Icon(TablerIcons.circle_check, color: COLOR_SUCCESS)
                      : serverStatus == false
                      ? Icon(TablerIcons.circle_x, color: COLOR_DANGER)
                      : Icon(TablerIcons.question_mark, color: COLOR_WARNING),
                  onPressed: serverChecking
                      ? null
                      : () async {
                          if (serverChecking) {
                            return;
                          }

                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          if (mounted) {
                            setState(() {
                              serverStatus = null;
                              serverChecking = true;
                            });
                          }

                          formKey.currentState!.save();

                          InvenTreeAPI().checkServer(server: server).then((
                            result,
                          ) {
                            if (mounted) {
                              setState(() {
                                serverStatus = result;
                                serverChecking = false;
                              });
                            }
                          });
                        },
                ),
              ),
            ],
          ),
          padding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}
