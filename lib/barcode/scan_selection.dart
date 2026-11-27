/*
 * Helpers for the camera barcode scanner:
 * - computing the scan window for the selected scan mode
 * - selecting a single barcode when several are detected in one frame
 */

import "dart:math";

import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";

/*
 * Compute the scan window, in the coordinate space of the scanner widget.
 *
 * - Square window (default): suitable for QR / 2D codes
 * - Strip window (linear mode): a wide, narrow rectangle,
 *   so that only one of several stacked 1D barcodes fits inside it
 */
Rect barcodeScanWindow(Size size, {bool linear = false}) {
  final Offset center = Offset(size.width / 2, size.height / 2);
  final double side = min(size.width, size.height);

  if (linear) {
    final double w = side * 0.9;
    return Rect.fromCenter(center: center, width: w, height: w * 0.3);
  }

  final double d = side * 0.8;
  return Rect.fromCenter(center: center, width: d, height: d);
}

/*
 * Select the barcode to use from a camera capture.
 *
 * - A single barcode is returned as-is
 * - With several barcodes, the one closest to the center of the image
 *   (i.e. the one the user is aiming at) is returned
 * - Returns null if there is no barcode, or if the choice is ambiguous
 *   (no clear winner, or barcode positions are unavailable)
 */
Barcode? selectCenteredBarcode(BarcodeCapture capture) {
  final List<Barcode> barcodes = capture.barcodes;

  if (barcodes.isEmpty) {
    return null;
  }

  if (barcodes.length == 1) {
    return barcodes.first;
  }

  final Size size = capture.size;

  if (size.isEmpty) {
    return null;
  }

  final Offset center = Offset(size.width / 2, size.height / 2);

  Barcode? best;
  double bestDistance = double.infinity;
  double secondDistance = double.infinity;

  for (final Barcode code in barcodes) {
    if (code.corners.isEmpty) {
      return null;
    }

    Offset c = Offset.zero;
    for (final Offset p in code.corners) {
      c += p;
    }
    c = c / code.corners.length.toDouble();

    final double distance = (c - center).distance;

    if (distance < bestDistance) {
      secondDistance = bestDistance;
      bestDistance = distance;
      best = code;
    } else if (distance < secondDistance) {
      secondDistance = distance;
    }
  }

  // Require a clear winner, to avoid picking the wrong code at random
  final double margin = min(size.width, size.height) * 0.05;

  if (secondDistance - bestDistance < margin) {
    return null;
  }

  return best;
}
