import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/settings/release.dart";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/widget/link_icon.dart";
import "package:package_info_plus/package_info_plus.dart";

import "package:inventree/l10.dart";
import "package:url_launcher/url_launcher.dart";

const String DOCS_URL = "https://docs.inventree.org/app";

class InvenTreeAboutWidget extends StatelessWidget {
  const InvenTreeAboutWidget(this.info) : super();

  final PackageInfo info;

  Future<void> _releaseNotes(BuildContext context) async {
    // Load release notes from external file
    String notes = await rootBundle.loadString("assets/release_notes.md");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReleaseNotesWidget(notes)),
    );
  }

  Future<void> _credits(BuildContext context) async {
    String notes = await rootBundle.loadString("assets/credits.md");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreditsWidget(notes)),
    );
  }

  Future<void> _openDocs() async {
    var docsUrl = Uri.parse(DOCS_URL);

    if (await canLaunchUrl(docsUrl)) {
      await launchUrl(docsUrl);
    }
  }

  Future<void> _reportBug(BuildContext context) async {
    var url = Uri(
      scheme: "https",
      host: "github.com",
      path: "inventree/inventree-app/issues/new/",
      queryParameters: {"title": "Enter bug description"},
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _translate() async {
    var url = Uri(
      scheme: "https",
      host: "crowdin.com",
      path: "/project/inventree",
    );

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
      ),
    );

    if (InvenTreeAPI().isConnected()) {
      tiles.add(
        ListTile(
          title: Text(L10().address),
          subtitle: Text(
            InvenTreeAPI().baseUrl.isNotEmpty
                ? InvenTreeAPI().baseUrl
                : L10().notConnected,
          ),
          leading: Icon(TablerIcons.globe),
          trailing: InvenTreeAPI().isConnected()
              ? Icon(TablerIcons.circle_check, color: COLOR_SUCCESS)
              : Icon(TablerIcons.circle_x, color: COLOR_DANGER),
        ),
      );

      tiles.add(
        ListTile(
          title: Text(L10().username),
          subtitle: Text(InvenTreeAPI().username),
          leading: InvenTreeAPI().username.isNotEmpty
              ? Icon(TablerIcons.user)
              : Icon(TablerIcons.user_cancel, color: COLOR_DANGER),
        ),
      );

      tiles.add(
        ListTile(
          title: Text(L10().version),
          subtitle: Text(
            InvenTreeAPI().serverVersion.isNotEmpty
                ? InvenTreeAPI().serverVersion
                : L10().notConnected,
          ),
          leading: Icon(TablerIcons.info_circle),
        ),
      );

      tiles.add(
        ListTile(
          title: Text(L10().serverInstance),
          subtitle: Text(
            InvenTreeAPI().serverInstance.isNotEmpty
                ? InvenTreeAPI().serverInstance
                : L10().notConnected,
          ),
          leading: Icon(TablerIcons.server),
        ),
      );

      // Display extra tile if the server supports plugins
      tiles.add(
        ListTile(
          title: Text(L10().pluginSupport),
          subtitle: Text(L10().pluginSupportDetail),
          leading: Icon(TablerIcons.plug),
        ),
      );
    } else {
      tiles.add(
        ListTile(
          title: Text(L10().notConnected),
          subtitle: Text(
            L10().serverNotConnected,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          leading: Icon(TablerIcons.exclamation_circle),
        ),
      );
    }

    tiles.add(
      ListTile(
        title: Text(
          L10().appDetails,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().packageName),
        subtitle: Text("${info.packageName}"),
        leading: Icon(TablerIcons.box),
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().version),
        subtitle: Text("${info.version} - Build ${info.buildNumber}"),
        leading: Icon(TablerIcons.info_circle),
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().releaseNotes),
        subtitle: Text(L10().appReleaseNotes),
        leading: Icon(TablerIcons.file, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () {
          _releaseNotes(context);
        },
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().credits),
        subtitle: Text(L10().appCredits),
        leading: Icon(TablerIcons.balloon, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () {
          _credits(context);
        },
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().documentation),
        subtitle: Text(DOCS_URL),
        leading: Icon(TablerIcons.book, color: COLOR_ACTION),
        trailing: LinkIcon(external: true),
        onTap: () {
          _openDocs();
        },
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().translate),
        subtitle: Text(L10().translateHelp),
        leading: Icon(TablerIcons.language, color: COLOR_ACTION),
        trailing: LinkIcon(external: true),
        onTap: () {
          _translate();
        },
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().reportBug),
        subtitle: Text(L10().reportBugDescription),
        leading: Icon(TablerIcons.bug, color: COLOR_ACTION),
        trailing: LinkIcon(external: true),
        onTap: () {
          _reportBug(context);
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(L10().appAbout),
        backgroundColor: COLOR_APP_BAR,
      ),
      body: ListView(
        children: ListTile.divideTiles(context: context, tiles: tiles).toList(),
      ),
    );
  }
}
