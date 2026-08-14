import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/progress.dart";

bool intentScannerActive = false;

final Stream<dynamic> datawedgeStream = const EventChannel(
  "inventree/datawedge_scans",
).receiveBroadcastStream();

class IntentBarcodeController extends InvenTreeBarcodeController {
  const IntentBarcodeController(
    BarcodeHandler handler, {
    super.key,
    this.initialBarcode,
  }) : super(handler);

  final String? initialBarcode;

  bool get isBackgroundScan => (initialBarcode ?? "").isNotEmpty;

  @override
  State<StatefulWidget> createState() => _IntentBarcodeControllerState();
}

class _IntentBarcodeControllerState extends InvenTreeBarcodeControllerState {
  StreamSubscription<dynamic>? _sub;

  bool canScan = true;
  bool get scanning => mounted && canScan;

  bool get isBackgroundScan =>
      (widget as IntentBarcodeController).isBackgroundScan;

  @override
  void initState() {
    super.initState();
    intentScannerActive = true;

    if (isBackgroundScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleBackgroundScan(
          (widget as IntentBarcodeController).initialBarcode ?? "",
        );
      });

      return;
    }

    _sub = datawedgeStream.listen((event) {
      if (!scanning) return;

      if (event is Map) {
        final map = Map<String, dynamic>.from(event);
        final data = (map["data"] ?? "").toString();
        if (data.isNotEmpty) {
          handleBarcodeData(data);
        }
      } else if (event is String && event.isNotEmpty) {
        handleBarcodeData(event);
      }
    });
  }

  Future<void> handleBackgroundScan(String barcode) async {
    if (!mounted || barcode.isEmpty) return;

    final NavigatorState navigator = Navigator.of(context);
    final ModalRoute<dynamic>? route = ModalRoute.of(context);

    showLoadingOverlay();

    try {
      await widget.handler.processBarcode(barcode);
    } finally {
      hideLoadingOverlay();

      if (route != null && route.isActive) {
        navigator.removeRoute(route);
      }
    }
  }

  @override
  void dispose() {
    intentScannerActive = false;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  @override
  Future<void> pauseScan() async {
    if (!mounted) return;
    setState(() {
      canScan = false;
    });
  }

  @override
  Future<void> resumeScan() async {
    if (!mounted) return;
    setState(() {
      canScan = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isBackgroundScan) {
      return const AbsorbPointer(child: SizedBox.expand());
    }

    return Scaffold(
      appBar: AppBar(title: Text(L10().scanBarcode)),
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 5),
            const Icon(TablerIcons.barcode, size: 64),
            const Spacer(flex: 5),
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                color: scanning ? COLOR_ACTION : COLOR_PROGRESS,
              ),
            ),
            const Spacer(flex: 5),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                widget.handler.getOverlayText(context),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
