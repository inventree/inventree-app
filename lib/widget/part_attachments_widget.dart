

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/widget/refreshable_state.dart';

import '../api.dart';
import '../l10.dart';

class PartAttachmentsWidget extends StatefulWidget {

  PartAttachmentsWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartAttachmentDisplayState createState() => _PartAttachmentDisplayState(part);
}


class _PartAttachmentDisplayState extends RefreshableState<PartAttachmentsWidget> {

  _PartAttachmentDisplayState(this.part);

  final InvenTreePart part;

  List<InvenTreePartAttachment> attachments = [];

  @override
  String getAppBarTitle(BuildContext context) => L10().attachments;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (false && InvenTreeAPI().checkPermission('part', 'change')) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.plus),
          onPressed: null,
        )
      );
    }

    return actions;
  }

  @override
  Future<void> request() async {

    await InvenTreePartAttachment().list(
      filters: {
        "part": "${part.pk}"
      }
    ).then((var results) {

      attachments.clear();

      for (var result in results) {
        if (result is InvenTreePartAttachment) {
          attachments.add(result);
        }
      }
    });

  }

  @override
  Widget getBody(BuildContext context) {
    return Center(
      child: ListView(
        children: ListTile.divideTiles(
          context: context,
          tiles: attachmentTiles(context)
        ).toList(),
      )
    );
  }


  List<Widget> attachmentTiles(BuildContext context) {

    List<Widget> tiles = [];

    for (var attachment in attachments) {
      tiles.add(ListTile(
        title: Text(attachment.filename),
        subtitle: Text(attachment.comment),
        leading: FaIcon(attachment.icon),
      ));
    }

    if (tiles.length == 0) {
      tiles.add(ListTile(
        title: Text(L10().attachmentNone),
        subtitle: Text(
            L10().attachmentNonePartDetail,
            style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ));
    }

    return tiles;

  }

}