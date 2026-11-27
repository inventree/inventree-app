import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/snacks.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:one_context/one_context.dart";
import "package:wakelock_plus/wakelock_plus.dart";

import "package:inventree/l10.dart";

import "package:inventree/barcode/handler.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/eci.dart";
import "package:inventree/barcode/scan_selection.dart";

/*
 * Barcode controller which uses the device's camera to scan barcodes.
 * Under the hood it uses the qr_code_scanner package.
 */
class CameraBarcodeController extends InvenTreeBarcodeController {
  const CameraBarcodeController(BarcodeHandler handler, {Key? key})
    : super(handler, key: key);

  @override
  State<StatefulWidget> createState() => _CameraBarcodeControllerState();
}

class _CameraBarcodeControllerState extends InvenTreeBarcodeControllerState {
  _CameraBarcodeControllerState() : super();

  bool flash_status = false;

  int scan_delay = 500;
  bool single_scanning = false;
  bool scanning_paused = false;
  bool multiple_barcodes = false;

  // Linear (1D) mode: use a narrow horizontal strip as the scan window,
  // so that only one of several stacked barcodes fits inside it
  bool linear_mode = false;

  String scanned_code = "";

  double zoomFactor = 0.0;

  final MobileScannerController controller = MobileScannerController(
    autoZoom: false, // Disable autoZoom as we implement a manual slider
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
    WakelockPlus.disable();
  }

  /*
   * Load the barcode scanning settings
   */
  Future<void> _loadSettings() async {
    bool _single = await InvenTreeSettingsManager().getBool(
      INV_BARCODE_SCAN_SINGLE,
      false,
    );

    int _delay =
        await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_DELAY, 500)
            as int;

    bool _linear = await InvenTreeSettingsManager().getBool(
      INV_BARCODE_SCAN_LINEAR,
      false,
    );

    if (mounted) {
      setState(() {
        scan_delay = _delay;
        single_scanning = _single;
        linear_mode = _linear;
        scanning_paused = false;
      });
    }
  }

  /*
   * Switch between the square (QR / 2D) and strip (linear barcode) scan window
   */
  Future<void> toggleLinearMode() async {
    final bool value = !linear_mode;

    if (mounted) {
      setState(() {
        linear_mode = value;
        multiple_barcodes = false;
      });
    }

    await InvenTreeSettingsManager().setValue(INV_BARCODE_SCAN_LINEAR, value);
  }

  /*
   * Compute the scan window, in the coordinate space of the scanner widget.
   * The same rectangle is used for the overlay, so what is drawn is what is scanned.
   */
  Rect scanWindowRect(Size size) =>
      barcodeScanWindow(size, linear: linear_mode);

  @override
  bool get isScanPaused => scanning_paused;

  @override
  Future<void> pauseScan() async {
    if (mounted) {
      setState(() {
        scanning_paused = true;
      });
    }
  }

  @override
  Future<void> resumeScan() async {
    controller.start();

    if (mounted) {
      setState(() {
        scanning_paused = false;
      });
    }
  }

  /*
   * Callback function when a barcode is scanned
   */
  Future<void> onScanSuccess(BarcodeCapture result) async {
    if (!mounted || scanning_paused) {
      return;
    }

    // TODO: Display outline of barcodes on the screen?

    if (result.barcodes.isEmpty) {
      setState(() {
        multiple_barcodes = false;
      });
      return;
    }

    // With several barcodes in view, use the one the user is aiming at
    Barcode? selected = selectCenteredBarcode(result);

    if (selected == null) {
      setState(() {
        multiple_barcodes = true;
      });
      return;
    }

    setState(() {
      multiple_barcodes = false;
    });

    String barcode = scannedValue(selected);

    if (barcode.isEmpty) {
      // TODO: Error message "empty barcode"
      return;
    }

    setState(() {
      scanned_code = barcode;
    });

    pauseScan();

    await handleBarcodeData(barcode).then((_) {
      if (!single_scanning && mounted) {
        resumeScan();
      }
    });

    resumeScan();

    if (mounted) {
      setState(() {
        scanned_code = "";
        multiple_barcodes = false;
      });
    }
  }

  /*
   * Text value of a scanned barcode.
   * For 2D codes, an ECI character-set marker that the scanner left in the
   * data is interpreted rather than passed on (see barcode/eci.dart).
   */
  String scannedValue(Barcode code) {
    final decoded = switch (code.rawDecodedBytes) {
      DecodedBarcodeBytes(:final bytes) => bytes,
      DecodedVisionBarcodeBytes(:final bytes) => bytes,
      null => null,
    };

    switch (code.format) {
      case BarcodeFormat.dataMatrix:
      case BarcodeFormat.qrCode:
      case BarcodeFormat.aztec:
      case BarcodeFormat.pdf417:
        return decodeEciPrefixed(code.rawValue, decoded);
      default:
        return code.rawValue ?? "";
    }
  }

  void onControllerCreated(CameraController? controller, Exception? error) {
    if (error != null) {
      sentryReportError(
        "CameraBarcodeController.onControllerCreated",
        error,
        null,
      );
    }

    if (controller == null) {
      showSnackIcon(
        L10().cameraCreationError,
        icon: TablerIcons.camera_x,
        success: false,
      );

      if (OneContext.hasContext) {
        Navigator.pop(OneContext().context!);
      }
    }
  }

  Widget BarcodeOverlay(BuildContext context, Size size) {
    final Rect window = scanWindowRect(size);

    // Color for the barcode scan?
    Color overlayColor = COLOR_ACTION;

    if (multiple_barcodes) {
      overlayColor = COLOR_DANGER;
    } else if (scanned_code.isNotEmpty) {
      overlayColor = COLOR_SUCCESS;
    } else if (scanning_paused) {
      overlayColor = COLOR_WARNING;
    }

    return Stack(
      children: [
        Positioned.fromRect(
          rect: window,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: overlayColor, width: 4),
            ),
            // Aiming line across the strip in linear mode
            child: linear_mode
                ? Center(
                    child: Container(
                      height: 2,
                      color: overlayColor.withValues(alpha: 0.7),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  /*
   * Build the barcode reader widget
   */
  Widget BarcodeReader(BuildContext context) {
    // Use the actual size of the scanner widget (not the whole screen),
    // otherwise the scan window is offset by the app bar height
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;

        return MobileScanner(
          controller: controller,
          overlayBuilder: (context, constraints) {
            return BarcodeOverlay(context, constraints.biggest);
          },
          scanWindow: scanWindowRect(size),
          onDetect: (result) {
            onScanSuccess(result);
          },
        );
      },
    );
  }

  Widget topCenterOverlay() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(left: 10, right: 10, top: 75, bottom: 10),
          child: Text(
            widget.handler.getOverlayText(context),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget bottomCenterOverlay() {
    String info_text = scanning_paused
        ? L10().barcodeScanPaused
        : L10().barcodeScanPause;

    String text = scanned_code.isNotEmpty ? scanned_code : info_text;

    if (text.length > 50) {
      text = text.substring(0, 50) + "...";
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 75),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget? buildActions(BuildContext context) {
    List<SpeedDialChild> actions = [
      SpeedDialChild(
        child: Icon(flash_status ? TablerIcons.bulb_off : TablerIcons.bulb),
        label: L10().toggleTorch,
        onTap: () async {
          controller.toggleTorch();
          if (mounted) {
            setState(() {
              flash_status = !flash_status;
            });
          }
        },
      ),
      SpeedDialChild(
        child: Icon(TablerIcons.camera),
        label: L10().switchCamera,
        onTap: () async {
          controller.switchCamera();
        },
      ),
    ];

    return SpeedDial(icon: Icons.more_horiz, children: actions);
  }

  Widget zoomSlider() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Center(
        child: Container(
          width: 225,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(28),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(TablerIcons.zoom_out, color: Colors.white, size: 20),
              Expanded(
                child: Slider(
                  value: zoomFactor,
                  min: 0.0,
                  max: 1.0,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withValues(alpha: 0.3),
                  onChanged: (value) {
                    setState(() {
                      zoomFactor = value;
                      controller.setZoomScale(value);
                    });
                  },
                  onChangeStart: (value) async {
                    if (mounted) {
                      setState(() {
                        scanning_paused = true;
                      });
                    }
                  },
                  onChangeEnd: (value) async {
                    if (mounted) {
                      setState(() {
                        scanning_paused = false;
                      });
                    }
                  },
                ),
              ),
              Icon(TablerIcons.zoom_in, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().scanBarcode),
        actions: [
          IconButton(
            icon: Icon(linear_mode ? TablerIcons.qrcode : TablerIcons.barcode),
            tooltip: linear_mode ? L10().scanModeSquare : L10().scanModeLinear,
            onPressed: toggleLinearMode,
          ),
          buildScanLogAction(),
        ],
      ),
      bottomNavigationBar: buildLastScanBar(),
      floatingActionButton: buildActions(context),
      body: GestureDetector(
        onTap: () async {
          if (mounted) {
            setState(() {
              // Toggle the 'scan paused' state
              scanning_paused = !scanning_paused;
            });
          }
        },
        child: Stack(
          children: <Widget>[
            Column(children: [Expanded(child: BarcodeReader(context))]),
            topCenterOverlay(),
            bottomCenterOverlay(),
            zoomSlider(),
          ],
        ),
      ),
    );
  }
}
