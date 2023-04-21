
import "dart:io";

import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:one_context/one_context.dart";
import "package:url_launcher/url_launcher.dart";

import "package:inventree/l10.dart";
import "package:inventree/app_colors.dart";

import "package:inventree/inventree/model.dart";

import "package:inventree/widget/fields.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/refreshable_state.dart";


/*
 * A generic widget for displaying a list of attachments.
 *
 * To allow use with different "types" of attachments,
 * we pass a subclassed instance of the InvenTreeAttachment model.
 */
class AttachmentWidget extends StatefulWidget {

  const AttachmentWidget(this.attachment, this.referenceId, this.hasUploadPermission) : super();

  final InvenTreeAttachment attachment;
  final int referenceId;
  final bool hasUploadPermission;

  @override
  _AttachmentWidgetState createState() => _AttachmentWidgetState();
}


class _AttachmentWidgetState extends RefreshableState<AttachmentWidget> {

  _AttachmentWidgetState();

  List<InvenTreeAttachment> attachments = [];

  @override
  String getAppBarTitle() => L10().attachments;

  @override
  List<Widget> appBarActions(BuildContext context) {
    if (!widget.hasUploadPermission) return [];

    return [
      IconButton(
        icon: FaIcon(FontAwesomeIcons.camera),
        onPressed: () async {
          FilePickerDialog.pickImageFromCamera().then((File? file) {
            upload(context, file);
          });
        }
      ),
      IconButton(
        icon: FaIcon(FontAwesomeIcons.fileArrowUp),
        onPressed: () async {
          FilePickerDialog.pickFileFromDevice().then((File? file) {
            upload(context, file);
          });
        }
      )
    ];
  }

  Future<void> upload(BuildContext context, File? file) async {

    if (file == null) return;

    showLoadingOverlay(context);
    final bool result = await widget.attachment.uploadAttachment(file, widget.referenceId);
    hideLoadingOverlay();

    if (result) {
      showSnackIcon(L10().uploadSuccess, success: true);
    } else {
      showSnackIcon(L10().uploadFailed, success: false);
    }

    refresh(context);
  }

  /*
   * Delete the specified attachment
   */
  Future<void> deleteAttachment(BuildContext context, InvenTreeAttachment attachment) async {

    final bool result = await attachment.delete();

    showSnackIcon(
      result ? L10().deleteSuccess : L10().deleteFailed,
      success: result
    );

    refresh(context);

  }

  /*
   * Display an option context menu for the selected attachment
   */
  Future<void> showOptionsMenu(BuildContext context, InvenTreeAttachment attachment) async {
    OneContext().showDialog(
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: Text(L10().attachments),
          children: [
            Divider(),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.of(ctx).pop();
                deleteAttachment(context, attachment);
              },
              child: ListTile(
                title: Text(L10().delete),
                leading: FaIcon(FontAwesomeIcons.trashCan),
              )
            )
          ]
        );
      }
    );
  }

  @override
  Future<void> request(BuildContext context) async {

    await widget.attachment.list(
      filters: {
        widget.attachment.REFERENCE_FIELD: widget.referenceId.toString()
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
  List<Widget> getTiles(BuildContext context) {

    List<Widget> tiles = [];

    // An "attachment" can either be a file, or a URL
    for (var attachment in attachments) {

      if (attachment.filename.isNotEmpty) {
        tiles.add(ListTile(
          title: Text(attachment.filename),
          subtitle: Text(attachment.comment),
          leading: FaIcon(attachment.icon, color: COLOR_ACTION),
          onTap: () async {
            showLoadingOverlay(context);
            await attachment.downloadAttachment();
            hideLoadingOverlay();
          },
          onLongPress: ()  {
            showOptionsMenu(context, attachment);
          },
        ));
      }

      else if (attachment.link.isNotEmpty) {
        tiles.add(ListTile(
          title: Text(attachment.link),
          subtitle: Text(attachment.comment),
          leading: FaIcon(FontAwesomeIcons.link, color: COLOR_ACTION),
          onTap: () async {
            var uri = Uri.tryParse(attachment.link.trimLeft());
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          onLongPress: ()  {
            showOptionsMenu(context, attachment);
          },
        ));
      }
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
