import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:inventree/preferences.dart";

const MethodChannel _channel = MethodChannel("inventree/wedge");

class WedgeDetectionResult {
  const WedgeDetectionResult({this.vendor = "none", this.supported = false});

  final String vendor;

  final bool supported;
}

Future<WedgeDetectionResult> detectWedgeScanner() async {
  if (kIsWeb || !Platform.isAndroid) {
    return const WedgeDetectionResult();
  }

  try {
    final Map<String, dynamic>? result = await _channel
        .invokeMapMethod<String, dynamic>("detectWedge");

    if (result == null) return const WedgeDetectionResult();

    return WedgeDetectionResult(
      vendor: (result["vendor"] ?? "none").toString(),
      supported: result["supported"] == true,
    );
  } catch (error) {
    return const WedgeDetectionResult();
  }
}

Future<void> applyWedgeDetection(WedgeDetectionResult result) async {
  if (result.supported) {
    await InvenTreeSettingsManager().setValue(
      INV_BARCODE_SCAN_TYPE,
      BARCODE_CONTROLLER_INTENT,
    );
  }

  await InvenTreeSettingsManager().setValue(INV_BARCODE_WEDGE_DETECTED, true);
}

Future<void> initWedgeScannerDefault() async {
  if (await InvenTreeSettingsManager().getBool(
    INV_BARCODE_WEDGE_DETECTED,
    false,
  )) {
    return;
  }

  final dynamic existing = await InvenTreeSettingsManager().getValue(
    INV_BARCODE_SCAN_TYPE,
    null,
  );

  if (existing != null) {
    await InvenTreeSettingsManager().setValue(INV_BARCODE_WEDGE_DETECTED, true);
    return;
  }

  await applyWedgeDetection(await detectWedgeScanner());
}
