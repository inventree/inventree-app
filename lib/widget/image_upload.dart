import "dart:io";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:one_context/one_context.dart";
import "package:path_provider/path_provider.dart" as path_provider;

import "package:inventree/l10.dart";
import "package:inventree/widget/part/image_cropper.dart";

const List<String> _kImageExtensions = [
  ".jpg",
  ".jpeg",
  ".png",
  ".bmp",
  ".gif",
  ".webp",
];

/// Return true if the provided file appears to be an image, based on its extension
bool isImageFile(File file) {
  final String path = file.path.toLowerCase();
  return _kImageExtensions.any((ext) => path.endsWith(ext));
}

/*
 * Common "pre-processing" step for any image file, applied before upload
 * (regardless of whether the image is destined for a Part, an Attachment, or elsewhere).
 *
 * - Files which are not images are returned unchanged.
 * - Image files are offered to the user for interactive cropping.
 *   If the user crops the image, the result is saved to a new temporary file and returned.
 *   Otherwise, the original file is returned unchanged.
 */
Future<File> preProcessImage(File imageFile) async {
  if (!isImageFile(imageFile)) {
    return imageFile;
  }

  final Uint8List imageBytes = await imageFile.readAsBytes();

  final Uint8List? croppedBytes = await OneContext().showDialog<Uint8List>(
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

  if (croppedBytes == null) {
    return imageFile;
  }

  final tempDir = await path_provider.getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final File tempFile = File("${tempDir.path}/cropped_image_$timestamp.jpg");
  await tempFile.writeAsBytes(croppedBytes);

  return tempFile;
}

/// Delete [processed] if it is a distinct temporary file created by [preProcessImage]
Future<void> cleanupProcessedImage(File original, File processed) async {
  if (processed.path == original.path) {
    return;
  }

  if (await processed.exists()) {
    await processed.delete().catchError((_) => processed);
  }
}
