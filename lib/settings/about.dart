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

    List<Widget> tiles = [];

    tiles.add(
      ListTile(
        title: Text(
          I18N.of(context).serverDetails,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      )
    );

    if (InvenTreeAPI().isConnected()) {
      tiles.add(
          ListTile(
            title: Text(I18N.of(context).address),
            subtitle: Text(InvenTreeAPI().baseUrl.isNotEmpty ? InvenTreeAPI().baseUrl : I18N.of(context).notConnected),
          )
      );

      tiles.add(
        ListTile(
          title: Text(I18N.of(context).version),
          subtitle: Text(InvenTreeAPI().version.isNotEmpty ? InvenTreeAPI().version : I18N.of(context).notConnected),
        )
      );

      tiles.add(
        ListTile(
          title: Text(I18N.of(context).serverInstance),
          subtitle: Text(InvenTreeAPI().instance.isNotEmpty ? InvenTreeAPI().instance : I18N.of(context).notConnected),
        )
      );
    } else {
      tiles.add(
        ListTile(
          title: Text(I18N.of(context).notConnected),
          subtitle: Text(
            I18N.of(context).serverNotConnected,
            style: TextStyle(fontStyle: FontStyle.italic),
          )
        )
      );
    }

    tiles.add(
      ListTile(
        title: Text(
          I18N.of(context).appDetails,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      )
    );

    tiles.add(
      ListTile(
      title: Text(I18N.of(context).name),
      subtitle: Text("${info.appName}"),
      )
    );

    tiles.add(
      ListTile(
        title: Text(I18N.of(context).packageName),
        subtitle: Text("${info.packageName}"),
      )
    );

    tiles.add(
      ListTile(
        title: Text(I18N.of(context).version),
        subtitle: Text("${info.version}"),
      )
    );

    tiles.add(
      ListTile(
        title: Text(I18N.of(context).build),
        subtitle: Text("${info.buildNumber}"),
      )
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(I18N.of(context).appAbout),
      ),
      body: ListView(
        children: ListTile.divideTiles(
          context: context,
          tiles: tiles,
        ).toList(),
      )
    );
  }
}