import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/settings/release.dart";

import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:package_info_plus/package_info_plus.dart";

import "package:inventree/l10.dart";
import "package:url_launcher/url_launcher.dart";

class InvenTreeAboutWidget extends StatelessWidget {

  const InvenTreeAboutWidget(this.info) : super();

  final PackageInfo info;

  Future <void> _releaseNotes(BuildContext context) async {

    // Load release notes from external file
    String notes = await rootBundle.loadString("assets/release_notes.md");

    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReleaseNotesWidget(notes))
    );
  }

  Future <void> _credits(BuildContext context) async {

    String notes = await rootBundle.loadString("assets/credits.md");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreditsWidget(notes))
    );
  }

  Future <void> _openDocs() async {

    const String docsUrl = "https://inventree.readthedocs.io/en/latest/app/app/";

    if (await canLaunch(docsUrl)) {
      await launch(docsUrl);
    }
  }

  Future <void> _reportBug(BuildContext context) async {

    const String url = "https://github.com/inventree/InvenTree/issues/new?assignees=&labels=app%2C+bug&title=%5BApp%5D+Enter+bug+description";

    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Future <void> _translate() async {
    const String url = "https://crowdin.com/project/inventree";

    if (await canLaunch(url)) {
      await launch(url);
    }
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
        leading: FaIcon(FontAwesomeIcons.fileAlt, color: COLOR_CLICK),
        onTap: () {
          _releaseNotes(context);
        },
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().credits),
        subtitle: Text(L10().appCredits),
        leading: FaIcon(FontAwesomeIcons.bullhorn, color: COLOR_CLICK),
        onTap: () {
          _credits(context);
        }
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().documentation),
        subtitle: Text("https://inventree.readthedocs.io"),
        leading: FaIcon(FontAwesomeIcons.book, color: COLOR_CLICK),
        onTap: () {
          _openDocs();
        },
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().translate),
        subtitle: Text(L10().translateHelp),
        leading: FaIcon(FontAwesomeIcons.language, color: COLOR_CLICK),
        onTap: () {
          _translate();
        }
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().reportBug),
        subtitle: Text(L10().reportBugDescription),
        leading: FaIcon(FontAwesomeIcons.bug, color: COLOR_CLICK),
        onTap: () {
        _reportBug(context);
        },
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