import 'package:InvenTree/inventree/sentry.dart';
import 'package:InvenTree/settings/about.dart';
import 'package:InvenTree/settings/app_settings.dart';
import 'package:InvenTree/settings/login.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:InvenTree/widget/dialogs.dart';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:InvenTree/l10.dart';

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
  final _feedbackKey = GlobalKey<FormState>();

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
                  leading: FaIcon(FontAwesomeIcons.server),
                  onTap: _editServerSettings,
              ),
              ListTile(
                leading: FaIcon(FontAwesomeIcons.cogs),
                title: Text(L10().appSettings),
                subtitle: Text(L10().appSettingsDetails),
                onTap: _editAppSettings,
              ),
              ListTile(
                title: Text(L10().about),
                subtitle: Text(L10().appDetails),
                leading: FaIcon(FontAwesomeIcons.infoCircle),
                onTap: _about,
              ),

              ListTile(
                title: Text(L10().documentation),
                subtitle: Text("https://inventree.readthedocs.io"),
                leading: FaIcon(FontAwesomeIcons.book),
                onTap: () {
                  _openDocs();
                },
              ),

              ListTile(
                title: Text(L10().translate),
                subtitle: Text(L10().translateHelp),
                leading: FaIcon(FontAwesomeIcons.language),
                onTap: () {
                  _translate();
                }
              ),

              ListTile(
                title: Text(L10().feedback),
                subtitle: Text(L10().submitFeedback),
                leading: FaIcon(FontAwesomeIcons.comments),
                onTap: () {
                  _submitFeedback(context);
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

  void _translate() async {
    final String url = "https://crowdin.com/project/inventree";

    if (await canLaunch(url)) {
      await launch(url);
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

  void _sendReport(BuildContext context, String message) async {
    bool result = await sentryReportMessage(message);

    if (result) {
      showSnackIcon(
        L10().feedbackSuccess,
        success: true,
      );
    } else {
      showSnackIcon(
        L10().feedbackError,
        success: false,
      );
    }
  }

  void _submitFeedback(BuildContext context) async {

    TextEditingController _controller = TextEditingController();

    _controller.clear();

    showFormDialog(
      L10().submitFeedback,
      key: _feedbackKey,
      callback: () {
        _sendReport(context, _controller.text);
      },
      fields: <Widget>[
        TextField(
          decoration: InputDecoration(
          ),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          controller: _controller
        )
      ]
    );
  }
}