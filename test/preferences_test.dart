/*
 * Unit tests for the preferences manager
 */

import "package:test/test.dart";
import "package:inventree/preferences.dart";

void main() {

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
  });
}