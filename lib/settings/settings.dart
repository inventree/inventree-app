import 'package:InvenTree/settings/about.dart';
import 'package:InvenTree/settings/app_settings.dart';
import 'package:InvenTree/settings/login.dart';
import 'package:InvenTree/user_profile.dart';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  final String docsUrl = "https://inventree.readthedocs.io/en/latest/app/app/";

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
                  title: Text(I18N.of(context).server),
                  subtitle: Text("Configure server settings"),
                  leading: FaIcon(FontAwesomeIcons.server),
                  onTap: _editServerSettings,
              ),
              ListTile(
                leading: FaIcon(FontAwesomeIcons.cogs),
                title: Text(I18N.of(context).appSettings),
                subtitle: Text(I18N.of(context).appSettingsDetails),
                onTap: _editAppSettings,
              ),
              ListTile(
                title: Text(I18N.of(context).about),
                subtitle: Text(I18N.of(context).appDetails),
                leading: FaIcon(FontAwesomeIcons.infoCircle),
                onTap: _about,
              ),

              ListTile(
                title: Text(I18N.of(context).documentation),
                subtitle: Text("https://inventree.readthedocs.io"),
                leading: FaIcon(FontAwesomeIcons.book),
                onTap: () {
                  _openDocs();
                },
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

    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget()));
  }

  void _editAppSettings() async {
    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeAppSettingsWidget()));
  }

  void _about() async {

    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)));
    });
  }
}