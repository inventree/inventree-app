import 'package:InvenTree/settings/about.dart';
import 'package:InvenTree/settings/login.dart';
import 'package:InvenTree/settings/release.dart';
import 'package:InvenTree/user_profile.dart';
import 'package:InvenTree/preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/api.dart';
import 'login.dart';

import 'package:package_info/package_info.dart';

class InvenTreeSettingsWidget extends StatefulWidget {
  // InvenTree settings view

  @override
  _InvenTreeSettingsState createState() => _InvenTreeSettingsState();

}


class _InvenTreeSettingsState extends State<InvenTreeSettingsWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18N.of(context).settings),
      ),
      body: Center(
        child: ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: <Widget>[
              ListTile(
                  title: Text(I18N.of(context).profile),
                  subtitle: Text("Configure user profile settings"),
                  leading: FaIcon(FontAwesomeIcons.user),
                  onTap: _editServerSettings,
              ),
              ListTile(
                title: Text(I18N.of(context).about),
                subtitle: Text(I18N.of(context).appDetails),
                leading: FaIcon(FontAwesomeIcons.infoCircle),
                onTap: _about,
              ),
              ListTile(
                title: Text(I18N.of(context).releaseNotes),
                subtitle: Text("Display app release notes"),
                leading: FaIcon(FontAwesomeIcons.fileAlt),
                onTap: _releaseNotes,
              ),
              ListTile(
                title: Text(I18N.of(context).reportBug),
                subtitle: Text("Report bug or suggest new feature"),
                leading: FaIcon(FontAwesomeIcons.bug),
                onTap: null,
              ),
            ]
          ).toList()
        )
      )
    );
  }

  void _editServerSettings() async {

    var prefs = await SharedPreferences.getInstance();

    List<UserProfile> profiles = await UserProfileDBManager().getAllProfiles();

    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget()));
  }

  void _about() async {

    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)));
    });
  }

  void _releaseNotes() async {

    // Load release notes from external file
    String notes = await rootBundle.loadString("assets/release_notes.md");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReleaseNotesWidget(notes))
    );
  }
}