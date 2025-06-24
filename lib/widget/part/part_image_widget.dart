import "dart:io";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart" as path_provider;
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/part/image_cropper.dart";
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

  Future<void> _processImageWithCropping(File imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Show the cropping dialog
      final Uint8List? croppedBytes = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  L10().cropImage,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(child: ImageCropperWidget(imageBytes: imageBytes)),
              ],
            ),
          ),
        ),
      );

      if (croppedBytes != null) {
        imageBytes = croppedBytes;
      }

      // Save cropped bytes to a proper temporary file for upload
      final tempDir = await path_provider.getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File("${tempDir.path}/cropped_image_$timestamp.jpg");
      await tempFile.writeAsBytes(imageBytes);

      // Upload the cropped file
      final result = await part.uploadImage(tempFile);

      // Delete temporary file
      if (await tempFile.exists()) {
        await tempFile.delete().catchError((_) => tempFile);
      }

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
                await _processImageWithCropping(file);
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
