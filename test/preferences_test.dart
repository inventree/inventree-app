/*
 * Unit tests for the preferences manager
 */

import "package:flutter_test/flutter_test.dart";
import "package:inventree/preferences.dart";

import "setup.dart";

void main() {
  setupTestEnv();

  setUp(() async {
  });

  group("Settings Tests:", () {
    test("Default Values", () async {
      // Boolean values
      expect(await InvenTreeSettingsManager().getBool("test", false), equals(false));
      expect(await InvenTreeSettingsManager().getBool("test", true), equals(true));

      // String values
      expect(await InvenTreeSettingsManager().getValue("test", "x"), equals("x"));
    });

    test("Set value", () async {
      await InvenTreeSettingsManager().setValue("abc", "xyz");

      expect(await InvenTreeSettingsManager().getValue("abc", "123"), equals("xyz"));
    });

    test("Booleans", () async {
      // Tests for boolean values

      await InvenTreeSettingsManager().removeValue("chicken");

      // Use default values when a setting does not exist
      assert(await InvenTreeSettingsManager().getBool("chicken", true) == true);
      assert(await InvenTreeSettingsManager().getBool("chicken", false) == false);

      // Explicitly set to true
      await InvenTreeSettingsManager().setValue("chicken", true);
      assert(await InvenTreeSettingsManager().getBool("chicken", false) == true);

      // Explicitly set to false
      await InvenTreeSettingsManager().setValue("chicken", false);
      assert(await InvenTreeSettingsManager().getBool("chicken", true) == false);

    });
  });
}