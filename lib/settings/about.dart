import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/settings/release.dart";

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

    var docsUrl = Uri(
        scheme: "https",
        host: "docs.inventree.org",
        path: "en/latest/app/app/");

    if (await canLaunchUrl(docsUrl)) {
      await launchUrl(docsUrl);
    }
  }

  Future <void> _reportBug(BuildContext context) async {

    var url = Uri(
        scheme: "https",
        host: "github.com",
        path: "inventree/inventree-app/issues/new?title=Enter+bug+description");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future <void> _translate() async {
    var url = Uri(
        scheme: "https",
        host: "crowdin.com",
        path: "/project/inventree");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
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
            trailing: InvenTreeAPI().isConnected() ? FaIcon(FontAwesomeIcons.circleCheck, color: COLOR_SUCCESS) : FaIcon(FontAwesomeIcons.circleXmark, color: COLOR_DANGER),
          )
      );

      tiles.add(
        ListTile(
          title: Text(L10().version),
          subtitle: Text(InvenTreeAPI().version.isNotEmpty ? InvenTreeAPI().version : L10().notConnected),
          leading: FaIcon(FontAwesomeIcons.circleInfo),
        )
      );

      tiles.add(
        ListTile(
          title: Text(L10().serverInstance),
          subtitle: Text(InvenTreeAPI().instance.isNotEmpty ? InvenTreeAPI().instance : L10().notConnected),
          leading: FaIcon(FontAwesomeIcons.server),
        )
      );

      // Display extra tile if the server supports plugins
      if (InvenTreeAPI().pluginsEnabled()) {
        tiles.add(
          ListTile(
            title: Text(L10().pluginSupport),
            subtitle: Text(L10().pluginSupportDetail),
            leading: FaIcon(FontAwesomeIcons.plug),
          )
        );
      }

    } else {
      tiles.add(
        ListTile(
          title: Text(L10().notConnected),
          subtitle: Text(
            L10().serverNotConnected,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          leading: FaIcon(FontAwesomeIcons.circleExclamation)
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
        leading: FaIcon(FontAwesomeIcons.circleInfo)
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().releaseNotes),
        subtitle: Text(L10().appReleaseNotes),
        leading: FaIcon(FontAwesomeIcons.fileLines, color: COLOR_CLICK),
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
        subtitle: Text("https://docs.inventree.org"),
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