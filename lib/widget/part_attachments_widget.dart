import "dart:io";

import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";

class PartAttachmentsWidget extends StatefulWidget {

  const PartAttachmentsWidget(this.part, {Key? key}) : super(key: key);

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

    if (InvenTreeAPI().checkPermission("part", "change")) {

      // File upload
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.plusCircle),
          onPressed: () async {
            FilePickerDialog.pickFile(
              onPicked: (File file) {
                upload(file);
              }
            );
          },
        )
      );
    }

    return actions;
  }

  Future<void> upload(File file) async {
    final bool result = await InvenTreePartAttachment().uploadAttachment(
      file,
      fields: {
        "part": "${part.pk}"
      }
    );

    if (result) {
      showSnackIcon(L10().uploadSuccess, success: true);
    } else {
      showSnackIcon(L10().uploadFailed, success: false);
    }

    refresh(context);
  }

  @override
  Future<void> request(BuildContext context) async {

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
        onTap: () async {
          await attachment.downloadAttachment();
        },
      ));
    }

    if (tiles.isEmpty) {
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