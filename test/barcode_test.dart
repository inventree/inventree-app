/*
 * Unit testing for barcode scanning functionality.
 *
 * As the unit testing framework cannot really "scan" barcode data,
 * we will mock the scanned data by passing raw "barcode" data to the scanning framework.
 */

import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/barcode.dart";
import "package:inventree/helpers.dart";
import "package:inventree/user_profile.dart";

void main() {

  // Connect to the server
  setUpAll(() async {
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
  });

  setUp(() async {
    // Clear the debug log
    clearDebugMessage();
  });

  group("Test BarcodeScanHandler:", () {
    // Tests for scanning a "generic" barcode

    var handler = BarcodeScanHandler();

    test("Empty Barcode", () async {
      // Handle an 'empty' barcode
      await handler.processBarcode(null, "");

      debugContains("Scanned barcode data: ''");
      debugContains("showSnackIcon: 'Barcode scan error'");

      assert(debugMessageCount() == 2);
    });

    test("Junk Data", () async {
      // test scanning 'junk' data

      await handler.processBarcode(null, "abcdefg");

      debugContains("Scanned barcode data: 'abcdefg'");
      debugContains("showSnackIcon: 'No match for barcode'");
    });

    test("Invalid StockLocation", () async {
      // Scan an invalid stock location
      await handler.processBarcode(null, "{'stocklocation': 999999}");

      debugContains("Scanned barcode data: '{'stocklocation': 999999}'");
      debugContains("showSnackIcon: 'No match for barcode'");
      assert(debugMessageCount() == 2);
    });

  });

  group("Test BarcodeScanStockLocationHandler:", () {
    // Tests for scanning a stock item into a location

    test("Scan Into Location", () async {
      // TODO
    });
  });
}