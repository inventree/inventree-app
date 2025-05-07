import "dart:io";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/widget/part/image_cropper.dart";
import "package:path_provider/path_provider.dart";
import "package:http/http.dart" as http;

import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/l10.dart";

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

  // Download the current image to a temporary file for cropping
  Future<File?> _downloadImageForCropping() async {
    try {
      if (part.image.isEmpty) {
        showSnackIcon(L10().noImageAvailable, success: false);
        return null;
      }

      // Get temp directory for storing the downloaded image
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          "${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg";

      // Create URL for the image
      final url = InvenTreeAPI().makeUrl(part.image);

      // Download image with the API headers
      final response = await http.get(
        Uri.parse(url),
        headers: InvenTreeAPI().defaultHeaders(),
      );

      if (response.statusCode != 200) {
        showSnackIcon(L10().downloadError, success: false);
        return null;
      }

      // Write image data to temp file
      final imageFile = File(tempPath);
      await imageFile.writeAsBytes(response.bodyBytes);

      return imageFile;
    } catch (e) {
      showSnackIcon("${L10().downloadError}: $e", success: false);
      return null;
    }
  }

  // Crop the image file
  Future<void> _cropImage(BuildContext context) async {
    try {
      final imageFile = await _downloadImageForCropping();

      if (imageFile == null) return;

      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

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
                Expanded(
                  child: ImageCropperWidget(imageBytes: imageBytes),
                ),
              ],
            ),
          ),
        ),
      );

      if (croppedBytes != null) {
        // Save cropped bytes to a new temporary file
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            "${tempDir.path}/cropped_image_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final croppedFile = File(tempPath);
        await croppedFile.writeAsBytes(croppedBytes);

        // Upload the cropped image
        final result = await part.uploadImage(croppedFile);

        if (!result) {
          showSnackIcon(L10().uploadFailed, success: false);
        } else {
          showSnackIcon(L10().uploadSuccess, success: true);
        }

        // Delete the temporary file after upload
        try {
          if (await croppedFile.exists()) {
            await croppedFile.delete();
          }
        } catch (e) {
          // Ignore deletion errors
        }

        refresh(context);
      }
    } catch (e) {
      showSnackIcon(L10().error, success: false);
    }
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (part.canEdit) {
      // Crop image button
      if (part.image.isNotEmpty) {
        actions.add(IconButton(
          icon: Icon(TablerIcons.crop),
          tooltip: L10().crop,
          onPressed: () async {
            await _cropImage(context);
          },
        ));
      }

      // File upload
      actions.add(IconButton(
        icon: Icon(TablerIcons.file_upload),
        tooltip: L10().uploadImage,
        onPressed: () async {

            FilePickerDialog.pickFile(
              onPicked: (File file) async {
                final result = await part.uploadImage(file);

                if (!result) {
                  showSnackIcon(L10().uploadFailed, success: false);
                }

                refresh(context);
              }
            );

          },
        )
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return InvenTreeAPI().getImage(part.image);
  }

}