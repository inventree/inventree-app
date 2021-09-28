import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_markdown/flutter_markdown.dart";
import "package:inventree/l10.dart";


class ReleaseNotesWidget extends StatelessWidget {

  final String releaseNotes;

  const ReleaseNotesWidget(this.releaseNotes);

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().releaseNotes)
      ),
      body: Markdown(
        selectable: false,
        data: releaseNotes,
      )
    );
  }
}


class CreditsWidget extends StatelessWidget {

  final String credits;

  const CreditsWidget(this.credits);

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().credits),
      ),
      body: Markdown(
        selectable: false,
        data: credits
      )
    );
  }
}