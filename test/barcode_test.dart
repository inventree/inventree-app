/*
 * Unit testing for barcode scanning functionality.
 *
 * As the unit testing framework cannot really "scan" barcode data,
 * we will mock the scanned data by passing raw "barcode" data to the scanning framework.
 */

import "dart:async";
// import "package:test/test.dart";
import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/barcode.dart";
import 'package:inventree/helpers.dart';
import "package:inventree/user_profile.dart";
import "package:inventree/inventree/stock.dart";

List<String> _log = [];
void print(String s) => _log.add(s);


void main() {

  // Connect to the server
  setUp(() async {

      final prf = await UserProfileDBManager().getProfileByName("Test Profile");

      if (prf != null) {
        UserProfileDBManager().deleteProfile(prf);
      }

      await UserProfileDBManager().addProfile(
        UserProfile(
          name: "Test Profile",
          server: "http://localhost:12345",
          username: "testuser",
          password: "testpassword",
          selected: true,
        ),
      );

    assert(await UserProfileDBManager().selectProfileByName("Test Profile"));
    assert(await InvenTreeAPI().connectToServer());

    // Clear the debug log
    clearDebugMessage();

  });

  group("ScanGenericBarcode:", () {
    // Tests for scanning a "generic" barcode

    var handler = BarcodeScanHandler();

    test("Empty Barcode", () async {
      // Handle an 'empty' barcode
      await handler.processBarcode(null, "");

      debugContains("Scanned barcode data: ''");
      debugContains("showSnackIcon: 'Barcode scan error'");

      assert(debugMessageCount() == 2);
    });

  });

  group("StockItemScanIntoLocation:", () {
    // Tests for scanning a stock item into a location

    test("Scan Into Location", () async {
      final InvenTreeStockItem? item = await InvenTreeStockItem().get(1) as InvenTreeStockItem?;

      assert(item != null);
      var handler = StockItemScanIntoLocationHandler(item!);

      // Scan "invalid" barcode data

    });
  });
}