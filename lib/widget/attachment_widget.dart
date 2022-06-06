/*
 * A generic widget for displaying a list of attachments.
 *
 * To allow use with different "types" of attachments,
 * we pass a subclassed instance of the InvenTreeAttachment model.
 */

import "dart:io";

import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";

class AttachmentWidget extends StatefulWidget {

  const AttachmentWidget(this.attachment, this.referenceId, this.hasUploadPermission) : super();

  final InvenTreeAttachment attachment;
  final int referenceId;
  final bool hasUploadPermission;

  @override
  _AttachmentWidgetState createState() => _AttachmentWidgetState(attachment, referenceId, hasUploadPermission);
}


class _AttachmentWidgetState extends RefreshableState<AttachmentWidget> {

  _AttachmentWidgetState(this.attachment, this.referenceId, this.hasUploadPermission);

  final InvenTreeAttachment attachment;
  final int referenceId;
  final bool hasUploadPermission;

  List<InvenTreeAttachment> attachments = [];

  @override
  String getAppBarTitle(BuildContext context) => L10().attachments;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (hasUploadPermission) {
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

    final bool result = await attachment.uploadAttachment(file, referenceId);

    if (result) {
      showSnackIcon(L10().uploadSuccess, success: true);
    } else {
      showSnackIcon(L10().uploadFailed, success: false);
    }

    refresh(context);
  }

  @override
  Future<void> request(BuildContext context) async {

    await attachment.list(
      filters: {
        attachment.REFERENCE_FIELD: referenceId.toString()
      }
    ).then((var results) {

      attachments.clear();

      for (var result in results) {
        if (result is InvenTreeAttachment) {
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
          L10().attachmentNoneDetail,
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ));
    }

    return tiles;
  }
}
