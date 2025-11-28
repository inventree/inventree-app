import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/attachment.dart";
import "package:inventree/widget/link_icon.dart";
import "package:one_context/one_context.dart";

import "package:inventree/l10.dart";
import "package:inventree/app_colors.dart";
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
  const AttachmentWidget(
    this.modelType,
    this.modelId,
    this.imagePrefix,
    this.hasUploadPermission,
  ) : super();

  final String modelType;
  final int modelId;
  final bool hasUploadPermission;
  final String imagePrefix;

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
        icon: Icon(TablerIcons.camera),
        onPressed: () async {
          InvenTreeAttachment().uploadImage(
            widget.modelType,
            widget.modelId,
            prefix: widget.imagePrefix
          ).then((_) {
            refresh(context);
          });
        },
      ),
      IconButton(
        icon: Icon(TablerIcons.file_upload),
        onPressed: () async {
          FilePickerDialog.pickFileFromDevice().then((File? file) {
            upload(context, file).then((_) {
              refresh(context);
            });
          });
        },
      ),
    ];
  }

  Future<void> upload(BuildContext context, File? file) async {
    if (file == null) return;

    showLoadingOverlay();

    final bool result = await InvenTreeAttachment().uploadAttachment(
      file,
      widget.modelType,
      widget.modelId,
    );

    hideLoadingOverlay();

    if (result) {
      showSnackIcon(L10().uploadSuccess, success: true);
    } else {
      showSnackIcon(L10().uploadFailed, success: false);
    }

    refresh(context);
  }

  Future<void> editAttachment(
    BuildContext context,
    InvenTreeAttachment attachment,
  ) async {
    attachment
        .editForm(context, L10().editAttachment)
        .then((result) => {refresh(context)});
  }

  /*
   * Delete the specified attachment
   */
  Future<void> deleteAttachment(
    BuildContext context,
    InvenTreeAttachment attachment,
  ) async {
    final bool result = await attachment.delete();

    showSnackIcon(
      result ? L10().deleteSuccess : L10().deleteFailed,
      success: result,
    );

    refresh(context);
  }

  /*
   * Display an option context menu for the selected attachment
   */
  Future<void> showOptionsMenu(
    BuildContext context,
    InvenTreeAttachment attachment,
  ) async {
    OneContext().showDialog(
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: Text(L10().attachments),
          children: [
            Divider(),
            SimpleDialogOption(
              onPressed: () async {
                OneContext().popDialog();
                editAttachment(context, attachment);
              },
              child: ListTile(
                title: Text(L10().edit),
                leading: Icon(TablerIcons.edit),
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                OneContext().popDialog();
                deleteAttachment(context, attachment);
              },
              child: ListTile(
                title: Text(L10().delete),
                leading: Icon(TablerIcons.trash, color: COLOR_DANGER),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Future<void> request(BuildContext context) async {
    Map<String, String> filters = {};

    filters["model_type"] = widget.modelType;
    filters["model_id"] = widget.modelId.toString();

    List<InvenTreeAttachment> _attachments = [];
    
    InvenTreeAttachment().list(filters: filters).then((var results) {

      for (var result in results) {
        if (result is InvenTreeAttachment) {
          _attachments.add(result);
        }
      }

      if (mounted) {
        setState(() {
          attachments = _attachments;
        });
      }
    });
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // An "attachment" can either be a file, or a URL
    for (var attachment in attachments) {
      if (attachment.filename.isNotEmpty) {
        tiles.add(
          ListTile(
            title: Text(attachment.filename),
            subtitle: Text(attachment.comment),
            leading: Icon(attachment.icon, color: COLOR_ACTION),
            onTap: () async {
              showLoadingOverlay();
              await attachment.downloadAttachment();
              hideLoadingOverlay();
            },
            onLongPress: () {
              showOptionsMenu(context, attachment);
            },
          ),
        );
      } else if (attachment.hasLink) {
        tiles.add(
          ListTile(
            title: Text(attachment.link),
            subtitle: Text(attachment.comment),
            leading: Icon(TablerIcons.link, color: COLOR_ACTION),
            onTap: () async {
              attachment.openLink();
            },
            onLongPress: () {
              showOptionsMenu(context, attachment);
            },
          ),
        );
      }
    }

    if (tiles.isEmpty) {
      tiles.add(
        ListTile(
          leading: Icon(TablerIcons.file_x, color: COLOR_WARNING),
          title: Text(L10().attachmentNone),
        ),
      );
    }

    return tiles;
  }
}


/*
 * Return a ListTile to display attachments for the specified model
 */
ListTile? ShowAttachmentsItem(
    BuildContext context,
    String modelType,
    int modelId,
    String imagePrefix,
    int attachmentCount,
    bool hasUploadPermission,
    ) {
  if (!InvenTreeAPI().supportsModernAttachments) {
    return null;
  }

  return ListTile(
      title: Text(L10().attachments),
      leading: Icon(TablerIcons.file, color: COLOR_ACTION),
      trailing: LinkIcon(
          text: attachmentCount > 0 ? attachmentCount.toString() : null
      ),
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    AttachmentWidget(
                      modelType,
                      modelId,
                      imagePrefix,
                      hasUploadPermission,
                    )
            )
        );
      }
  );
}
