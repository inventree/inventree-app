import 'package:InvenTree/inventree/sentry.dart';
import 'package:InvenTree/settings/about.dart';
import 'package:InvenTree/settings/login.dart';
import 'package:InvenTree/user_profile.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/snacks.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login.dart';

import 'package:package_info/package_info.dart';

class InvenTreeSettingsWidget extends StatefulWidget {
  // InvenTree settings view

  @override
  _InvenTreeSettingsState createState() => _InvenTreeSettingsState();

}


class _InvenTreeSettingsState extends State<InvenTreeSettingsWidget> {

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _bugKey = GlobalKey<FormState>();

  final String docsUrl = "https://inventree.rtfd.io";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
                title: Text(I18N.of(context).documentation),
                subtitle: Text(docsUrl),
                leading: FaIcon(FontAwesomeIcons.book),
                onTap: () {
                  _openDocs();
                },
              ),

              ListTile(
                title: Text(I18N.of(context).reportBug),
                subtitle: Text("Report bug or suggest new feature"),
                leading: FaIcon(FontAwesomeIcons.bug),
                onTap: _reportBug,
              ),
            ]
          ).toList()
        )
      )
    );
  }


  void _openDocs() async {
    if (await canLaunch(docsUrl)) {
      await launch(docsUrl);
    }
  }

  void _editServerSettings() async {

    List<UserProfile> profiles = await UserProfileDBManager().getAllProfiles();

    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget()));
  }

  void _about() async {

    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)));
    });
  }

  void _sendReport(String message) async {

    bool result = await sentryReportMessage(message);

    if (result) {
      showSnackIcon(_scaffoldKey, "Uploaded report", success: true);
    } else {
      showSnackIcon(_scaffoldKey, "Report upload failed", success: false);
    }
  }

  void _reportBug() async {

    TextEditingController _controller = TextEditingController();

    _controller.clear();

    showFormDialog(
      context,
      "Upload Bug Report",
      key: _bugKey,
      callback: () {
        _sendReport(_controller.text);
      },
      fields: <Widget>[
        TextField(
          decoration: InputDecoration(
            hintText: "Enter bug report details",
          ),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          controller: _controller
        ),
      ]
    );

  }
}