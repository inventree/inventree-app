import 'package:InvenTree/api.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info/package_info.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class InvenTreeAboutWidget extends StatelessWidget {

  final PackageInfo info;

  InvenTreeAboutWidget(this.info) : super();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("About InvenTree"),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text(I18N.of(context).serverDetails),
          ),
          ListTile(
            title: Text(I18N.of(context).address),
            subtitle: Text(InvenTreeAPI().baseUrl.isNotEmpty ? InvenTreeAPI().baseUrl : "Not connected"),
          ),
          ListTile(
            title: Text(I18N.of(context).version),
            subtitle: Text(InvenTreeAPI().version.isNotEmpty ? InvenTreeAPI().version : "Not connected"),
          ),
          ListTile(
            title: Text("Server Instance"),
            subtitle: Text(InvenTreeAPI().instance.isNotEmpty ? InvenTreeAPI().instance : "Not connected"),
          ),
          Divider(),
          ListTile(
            title: Text(I18N.of(context).appDetails),
          ),
          ListTile(
            title: Text(I18N.of(context).name),
            subtitle: Text("${info.appName}"),
          ),
          ListTile(
            title: Text("Package Name"),
            subtitle: Text("${info.packageName}"),
          ),
          ListTile(
            title: Text(I18N.of(context).version),
            subtitle: Text("${info.version}"),
          ),
          ListTile(
              title: Text(I18N.of(context).build),
              subtitle: Text("${info.buildNumber}"),
          )
        ],
      )
    );
  }
}