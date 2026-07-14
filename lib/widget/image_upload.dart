import "dart:io";
import "dart:typed_data";

import "package:flutter/foundation.dart" show compute;
import "package:flutter/material.dart";
import "package:image/image.dart" as img;
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

enum _ImageProcessChoice { crop, useOriginal }

/*
 * Common "pre-processing" step for any image file, applied before upload
 * (regardless of whether the image is destined for a Part, an Attachment, or elsewhere).
 *
 * - Files which are not images are returned unchanged.
 * - Image files prompt the user to either crop the image, or upload it as-is.
 * - If the user cancels at any point (the initial prompt, or the crop screen itself),
 *   this returns null, and the caller must abort the upload entirely.
 */
Future<File?> preProcessImage(File imageFile) async {
  if (!isImageFile(imageFile)) {
    return imageFile;
  }

  final _ImageProcessChoice? choice = await OneContext()
      .showDialog<_ImageProcessChoice>(
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(L10().cropImage),
          content: Text(L10().cropImagePrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(L10().cancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_ImageProcessChoice.crop),
              child: Text(L10().crop),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(_ImageProcessChoice.useOriginal),
              child: Text(L10().useOriginal),
            ),
          ],
        ),
      );

  if (choice == null) {
    // User cancelled - abort the upload entirely
    return null;
  }

  if (choice == _ImageProcessChoice.useOriginal) {
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
    // User cancelled the crop screen - abort the upload entirely
    return null;
  }

  // The crop widget always hands back uncompressed PNG data,
  // regardless of the source format - re-encode as JPEG so we
  // don't upload a file many times larger than the original photo.
  // Run this on a background isolate: decode/encode are synchronous,
  // CPU-heavy calls that would otherwise freeze the UI thread.
  final List<int> jpegBytes = await compute(_encodeAsJpeg, croppedBytes);

  final tempDir = await path_provider.getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final File tempFile = File("${tempDir.path}/cropped_image_$timestamp.jpg");
  await tempFile.writeAsBytes(jpegBytes);

  return tempFile;
}

/// Decode [pngBytes] and re-encode as JPEG. Runs on a background isolate via [compute].
List<int> _encodeAsJpeg(Uint8List pngBytes) {
  final img.Image? decoded = img.decodeImage(pngBytes);
  return decoded != null ? img.encodeJpg(decoded, quality: 90) : pngBytes;
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
