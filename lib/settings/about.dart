import 'package:InvenTree/api.dart';
import 'package:InvenTree/settings/release.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info/package_info.dart';

import 'package:InvenTree/l10.dart';

class InvenTreeAboutWidget extends StatelessWidget {

  final PackageInfo info;

  InvenTreeAboutWidget(this.info) : super();

  void _releaseNotes(BuildContext context) async {

    // Load release notes from external file
    String notes = await rootBundle.loadString("assets/release_notes.md");

    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReleaseNotesWidget(notes))
    );
  }

  void _credits(BuildContext context) async {

    String notes = await rootBundle.loadString("assets/credits.md");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreditsWidget(notes))
    );
  }

  @override
  Widget build(BuildContext context) {

    List<Widget> tiles = [];

    tiles.add(
      ListTile(
        title: Text(
          L10().serverDetails,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      )
    );

    if (InvenTreeAPI().isConnected()) {
      tiles.add(
          ListTile(
            title: Text(L10().address),
            subtitle: Text(InvenTreeAPI().baseUrl.isNotEmpty ? InvenTreeAPI().baseUrl : L10().notConnected),
            leading: FaIcon(FontAwesomeIcons.globe),
          )
      );

      tiles.add(
        ListTile(
          title: Text(L10().version),
          subtitle: Text(InvenTreeAPI().version.isNotEmpty ? InvenTreeAPI().version : L10().notConnected),
          leading: FaIcon(FontAwesomeIcons.infoCircle),
        )
      );

      tiles.add(
        ListTile(
          title: Text(L10().serverInstance),
          subtitle: Text(InvenTreeAPI().instance.isNotEmpty ? InvenTreeAPI().instance : L10().notConnected),
          leading: FaIcon(FontAwesomeIcons.server),
        )
      );
    } else {
      tiles.add(
        ListTile(
          title: Text(L10().notConnected),
          subtitle: Text(
            L10().serverNotConnected,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          leading: FaIcon(FontAwesomeIcons.exclamationCircle)
        )
      );
    }

    tiles.add(
      ListTile(
        title: Text(
          L10().appDetails,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().packageName),
        subtitle: Text("${info.packageName}"),
        leading: FaIcon(FontAwesomeIcons.box)
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().version),
        subtitle: Text("${info.version} - Build ${info.buildNumber}"),
        leading: FaIcon(FontAwesomeIcons.infoCircle)
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().releaseNotes),
        subtitle: Text(L10().appReleaseNotes),
        leading: FaIcon(FontAwesomeIcons.fileAlt),
        onTap: () {
          _releaseNotes(context);
        },
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().credits),
        subtitle: Text(L10().appCredits),
        leading: FaIcon(FontAwesomeIcons.bullhorn),
        onTap: () {
          _credits(context);
        }
      )
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(L10().appAbout),
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