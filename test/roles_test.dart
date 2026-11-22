/*
 * Unit tests for the user roles required by each model (regression tests for B9).
 *
 * The server has split some data out of the "part" role into separate roles:
 * - part_category (API v335)
 * - bom           (API v481)
 * - pricing       (API v562)
 *
 * No server is required.
 */

import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/bom.dart";
import "package:inventree/inventree/part.dart";

void main() {
  void setApiVersion(int version) {
    InvenTreeAPI().serverInfo = {"apiVersion": version};
  }

  tearDown(() {
    InvenTreeAPI().serverInfo = {};
  });

  group("Part Category:", () {
    test("Older server uses part role", () {
      setApiVersion(334);
      expect(InvenTreeAPI().supportsPartCategoryRole, isFalse);
      expect(InvenTreePartCategory().rolesRequired, equals(["part"]));
    });

    test("Newer server uses part_category role", () {
      setApiVersion(335);
      expect(InvenTreeAPI().supportsPartCategoryRole, isTrue);
      expect(InvenTreePartCategory().rolesRequired, equals(["part_category"]));
    });
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

  test("Part role is unchanged", () {
    for (final version in [314, 335, 481, 562, 568]) {
      setApiVersion(version);
      expect(InvenTreePart().rolesRequired, equals(["part"]));
    }
  });
}
