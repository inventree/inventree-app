/*
 * Unit tests for the user roles required by each model (regression tests for B9).
 *
 * Roles which exist on all supported servers (since 2021):
 * - part_category
 * - stock_location
 *
 * Roles split out of the "part" role on newer servers:
 * - bom           (API v481)
 * - pricing       (API v562)
 *
 * No server is required.
 */

import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/bom.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";

void main() {
  void setApiVersion(int version) {
    InvenTreeAPI().serverInfo = {"apiVersion": version};
  }

  tearDown(() {
    InvenTreeAPI().serverInfo = {};
  });

  test("Part category and stock location roles", () {
    for (final version in [314, 481, 562, 568]) {
      setApiVersion(version);

      expect(InvenTreePartCategory().rolesRequired, equals(["part_category"]));
      expect(
        InvenTreeStockLocation().rolesRequired,
        equals(["stock_location"]),
      );

      // Parts and stock items keep their own roles
      expect(InvenTreePart().rolesRequired, equals(["part"]));
      expect(InvenTreeStockItem().rolesRequired, equals(["stock"]));
    }
  });

  group("BOM Item:", () {
    test("Older server uses part role", () {
      setApiVersion(480);
      expect(InvenTreeAPI().supportsBomRole, isFalse);
      expect(InvenTreeBomItem().rolesRequired, equals(["part"]));
    });

    test("Newer server uses bom role", () {
      setApiVersion(481);
      expect(InvenTreeAPI().supportsBomRole, isTrue);
      expect(InvenTreeBomItem().rolesRequired, equals(["bom"]));
    });
  });

  group("Part Pricing:", () {
    test("Older server uses part role", () {
      setApiVersion(561);
      expect(InvenTreeAPI().supportsPricingRole, isFalse);
      expect(InvenTreePartPricing().rolesRequired, equals(["part"]));
    });

    test("Newer server uses pricing role", () {
      setApiVersion(562);
      expect(InvenTreeAPI().supportsPricingRole, isTrue);
      expect(InvenTreePartPricing().rolesRequired, equals(["pricing"]));
    });
  });
}
