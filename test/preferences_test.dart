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
    });
  });
}