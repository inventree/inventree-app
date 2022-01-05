import "package:inventree/app_colors.dart";
import "package:inventree/settings/about.dart";
import "package:inventree/settings/app_settings.dart";
import "package:inventree/settings/login.dart";

import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/l10.dart";

import "package:url_launcher/url_launcher.dart";

import "package:package_info_plus/package_info_plus.dart";

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
        title: Text(L10().settings),
      ),
      body: Center(
        child: ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: <Widget>[
              ListTile(
                  title: Text(L10().server),
                  subtitle: Text(L10().configureServer),
                  leading: FaIcon(FontAwesomeIcons.server, color: COLOR_CLICK),
                  onTap: _editServerSettings,
              ),
              ListTile(
                title: Text(L10().appSettings),
                subtitle: Text(L10().appSettingsDetails),
                leading: FaIcon(FontAwesomeIcons.cogs, color: COLOR_CLICK),
                onTap: _editAppSettings,
              ),
              ListTile(
                title: Text(L10().about),
                subtitle: Text(L10().appDetails),
                leading: FaIcon(FontAwesomeIcons.infoCircle, color: COLOR_CLICK),
                onTap: _about,
              ),

              ListTile(
                title: Text(L10().documentation),
                subtitle: Text("https://inventree.readthedocs.io"),
                leading: FaIcon(FontAwesomeIcons.book, color: COLOR_CLICK),
                onTap: () {
                  _openDocs();
                },
              ),

              ListTile(
                title: Text(L10().translate),
                subtitle: Text(L10().translateHelp),
                leading: FaIcon(FontAwesomeIcons.language, color: COLOR_CLICK),
                onTap: () {
                  _translate();
                }
              ),

              ListTile(
                title: Text(L10().reportBug),
                subtitle: Text(L10().reportBugDescription),
                leading: FaIcon(FontAwesomeIcons.bug, color: COLOR_CLICK),
                onTap: () {
                  _reportBug(context);
                },
              ),

            ]
          ).toList()
        )
      )
    );
  }


  Future <void> _openDocs() async {
    if (await canLaunch(docsUrl)) {
      await launch(docsUrl);
    }
  }

  Future <void> _translate() async {
    const String url = "https://crowdin.com/project/inventree";

    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Future <void> _editServerSettings() async {

    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget()));
  }

  Future <void> _editAppSettings() async {
    Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeAppSettingsWidget()));
  }

  Future <void> _about() async {

    PackageInfo.fromPlatform().then((PackageInfo info) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => InvenTreeAboutWidget(info)));
    });
  }

  Future <void> _reportBug(BuildContext context) async {

    const String url = "https://github.com/inventree/InvenTree/issues/new?assignees=&labels=app%2C+bug&title=%5BApp%5D+Enter+bug+description";

    if (await canLaunch(url)) {
      await launch(url);
    }
  }

}