import 'package:InvenTree/api.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info/package_info.dart';

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
            title: Text("Server Address"),
            subtitle: Text(InvenTreeAPI().baseUrl.isNotEmpty ? InvenTreeAPI().baseUrl : "Not connected"),
          ),
          ListTile(
            title: Text("Server Version"),
            subtitle: Text(InvenTreeAPI().version.isNotEmpty ? InvenTreeAPI().version : "Not connected"),
          ),
          ListTile(
            title: Text("Server Instance"),
            subtitle: Text(InvenTreeAPI().instance.isNotEmpty ? InvenTreeAPI().instance : "Not connected"),
          ),
          Divider(),
          ListTile(
            title: Text("App Name"),
            subtitle: Text("${info.appName}"),
          ),
          ListTile(
            title: Text("Package Name"),
            subtitle: Text("${info.packageName}"),
          ),
          ListTile(
            title: Text("App Version"),
            subtitle: Text("${info.version}"),
          ),
          ListTile(
              title: Text("Build Number"),
              subtitle: Text("${info.buildNumber}")
          ),
          Divider(),
          ListTile(
            title: Text("Submit Bug Report"),
            subtitle: Text("https://github.com/inventree/inventree-app/issues/"),
            onTap: () {
              // TODO - Open the URL in an external webpage?
            },
          )
        ],
      )
    );
  }
}