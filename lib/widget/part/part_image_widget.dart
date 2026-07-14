import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/image_upload.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

class PartImageWidget extends StatefulWidget {
  const PartImageWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartImageState createState() => _PartImageState(part);
}

class _PartImageState extends RefreshableState<PartImageWidget> {
  _PartImageState(this.part);

  final InvenTreePart part;

  @override
  Future<void> request(BuildContext context) async {
    await part.reload();
  }

  @override
  String getAppBarTitle() => part.fullname;

  Future<void> _uploadImage(File imageFile) async {
    try {
      final File? processed = await preProcessImage(imageFile);

      if (processed == null) {
        // User cancelled the upload
        return;
      }

      final bool result = await part.uploadImage(processed);

      await cleanupProcessedImage(imageFile, processed);

      if (!result) {
        showSnackIcon(L10().uploadFailed, success: false);
      } else {
        showSnackIcon(L10().uploadSuccess, success: true);
      }

      refresh(context);
    } catch (e) {
      showSnackIcon("${L10().error}: $e", success: false);
    }
  }

  // Delete the current part image
  Future<void> _deleteImage() async {
    // Confirm deletion with user
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(L10().deleteImage),
            content: Text(L10().deleteImageConfirmation),
            actions: [
              TextButton(
                child: Text(L10().cancel),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text(L10().delete),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      final APIResponse response = await InvenTreeAPI().patch(
        part.url,
        body: {"image": null},
      );

      if (response.successful()) {
        showSnackIcon(L10().deleteSuccess, success: true);
      } else {
        showSnackIcon(
          "${L10().deleteFailed}: ${response.error}",
          success: false,
        );
      }

      refresh(context);
    }
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [
      if (part.canEdit) ...[
        // Delete image button
        if (part.jsondata["image"] != null)
          IconButton(
            icon: Icon(TablerIcons.trash),
            tooltip: L10().deleteImageTooltip,
            onPressed: _deleteImage,
          ),

        // File upload with cropping
        IconButton(
          icon: Icon(TablerIcons.file_upload),
          tooltip: L10().uploadImage,
          onPressed: () async {
            FilePickerDialog.pickFile(
              onPicked: (File file) async {
                await _uploadImage(file);
              },
            );
          },
        ),
      ],
    ];

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return Center(child: InvenTreeAPI().getImage(part.image));
  }
}
