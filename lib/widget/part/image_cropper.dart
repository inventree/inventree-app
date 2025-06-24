import "dart:typed_data";
import "package:custom_image_crop/custom_image_crop.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/l10.dart";

/// Widget for displaying the image cropper UI
class ImageCropperWidget extends StatefulWidget {
  const ImageCropperWidget({Key? key, required this.imageBytes})
    : super(key: key);

  final Uint8List imageBytes;

  @override
  State<ImageCropperWidget> createState() => _ImageCropperWidgetState();
}

class _ImageCropperWidgetState extends State<ImageCropperWidget> {
  final cropController = CustomImageCropController();

  // Define fixed ratio objects so they are the same instances for comparison
  static final _ratioSquare = Ratio(width: 1, height: 1);
  static final _ratio4x3 = Ratio(width: 4, height: 3);
  static final _ratio16x9 = Ratio(width: 16, height: 9);
  static final _ratio3x2 = Ratio(width: 3, height: 2);

  var _aspectRatio = _ratioSquare;
  var _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<Ratio>(
                value: _aspectRatio,
                items: [
                  DropdownMenuItem(
                    value: _ratioSquare,
                    child: Text(L10().aspectRatioSquare),
                  ),
                  DropdownMenuItem(
                    value: _ratio4x3,
                    child: Text(L10().aspectRatio4x3),
                  ),
                  DropdownMenuItem(
                    value: _ratio16x9,
                    child: Text(L10().aspectRatio16x9),
                  ),
                  DropdownMenuItem(
                    value: _ratio3x2,
                    child: Text(L10().aspectRatio3x2),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _aspectRatio = value;
                    });
                  }
                },
              ),

              // Reset button - returns the image to its default state
              IconButton(
                icon: Icon(TablerIcons.refresh),
                onPressed: () => cropController.reset(),
                tooltip: "Reset",
              ),

              // Zoom out button - scales to 75% of current size
              IconButton(
                icon: Icon(TablerIcons.zoom_out),
                onPressed: () =>
                    cropController.addTransition(CropImageData(scale: 0.75)),
                tooltip: "Zoom Out",
              ),

              // Zoom in button - scales to 133% of current size
              IconButton(
                icon: Icon(TablerIcons.zoom_in),
                onPressed: () =>
                    cropController.addTransition(CropImageData(scale: 1.33)),
                tooltip: "Zoom In",
              ),

              // Rotate button
              IconButton(
                icon: Icon(TablerIcons.rotate),
                onPressed: () =>
                    cropController.addTransition(CropImageData(angle: 90)),
                tooltip: L10().rotateClockwise,
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomImageCrop(
              cropController: cropController,
              image: MemoryImage(widget.imageBytes),
              shape: CustomCropShape.Ratio,
              ratio: _aspectRatio,
              forceInsideCropArea: true,
              overlayColor: Colors.black.withAlpha(128),
              backgroundColor: Colors.black.withAlpha(64),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(L10().cancel),
              ),
              ElevatedButton(
                onPressed: _isCropping
                    ? null
                    : () async {
                        setState(() {
                          _isCropping = true;
                        });

                        try {
                          // Crop the image
                          final image = await cropController.onCropImage();
                          if (!mounted) return;
                          if (image != null) {
                            Navigator.of(context).pop(image.bytes);
                          } else {
                            setState(() {
                              _isCropping = false;
                            });
                          }
                        } catch (e) {
                          if (!mounted) return;
                          setState(() {
                            _isCropping = false;
                          });
                        }
                      },
                child: _isCropping
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Colors.white,
                        ),
                      )
                    : Text(L10().crop),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
