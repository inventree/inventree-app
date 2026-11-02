/*
 * Unit tests for parsing of managed (MDM) configuration values
 */

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:inventree/managed_config.dart";

void main() {
  group("Managed Setting:", () {
    test("Null Value", () async {
      for (final type in ManagedSettingType.values) {
        expect(ManagedSetting("key", type).parse(null), isNull);
      }
    });

    test("Boolean", () async {
      const setting = ManagedSetting("key", ManagedSettingType.boolean);

      for (final value in [true, "true", " TRUE ", "1", 1, "yes", "On"]) {
        expect(setting.parse(value), isTrue, reason: "value: '${value}'");
      }

      for (final value in [false, "false", "0", 0, "No", "off"]) {
        expect(setting.parse(value), isFalse, reason: "value: '${value}'");
      }

      for (final value in ["", "maybe", 2, "truthy"]) {
        expect(setting.parse(value), isNull, reason: "value: '${value}'");
      }
    });

    test("Integer", () async {
      const setting = ManagedSetting("key", ManagedSettingType.integer);

      expect(setting.parse(5), equals(5));
      expect(setting.parse(7.9), equals(7));
      expect(setting.parse(" 42 "), equals(42));
      expect(setting.parse("-3"), equals(-3));
      expect(setting.parse("abc"), isNull);
      expect(setting.parse("1.5"), isNull);
    });

    test("Integer Limits", () async {
      const setting = ManagedSetting(
        "key",
        ManagedSettingType.integer,
        minimum: 1,
        maximum: 10,
      );

      expect(setting.parse(5), equals(5));
      expect(setting.parse(0), equals(1));
      expect(setting.parse("-100"), equals(1));
      expect(setting.parse(11), equals(10));
      expect(setting.parse("1000"), equals(10));
    });

    test("Choice", () async {
      const setting = ManagedSetting(
        "key",
        ManagedSettingType.choice,
        choices: {"System": 0, "portrait": 1, "landscape": 2},
      );

      // Match by name (case insensitive)
      expect(setting.parse("system"), equals(0));
      expect(setting.parse(" PORTRAIT "), equals(1));
      expect(setting.parse("Landscape"), equals(2));

      // Match by value
      expect(setting.parse(2), equals(2));
      expect(setting.parse("1"), equals(1));

      // No match
      expect(setting.parse("sideways"), isNull);
      expect(setting.parse(3), isNull);
      expect(setting.parse("-1"), isNull);
    });

    test("Managed Settings List", () async {
      // Every managed setting must have a unique key
      final keys = MANAGED_SETTINGS.map((s) => s.key).toList();
      expect(keys.toSet().length, equals(keys.length));

      for (final setting in MANAGED_SETTINGS) {
        if (setting.type == ManagedSettingType.choice) {
          expect(setting.choices, isNotEmpty, reason: setting.key);
        }
      }
    });
  });

  group("Managed Locale:", () {
    test("Exact Match", () async {
      expect(matchSupportedLocale("de_DE"), equals(const Locale("de", "DE")));
      expect(matchSupportedLocale("pt-PT"), equals(const Locale("pt", "PT")));
      expect(matchSupportedLocale("zh_tw"), equals(const Locale("zh", "TW")));
      expect(matchSupportedLocale(" en "), equals(const Locale("en", "")));
    });

    test("Language Match", () async {
      // Falls back to the first supported locale for the language
      expect(matchSupportedLocale("fr"), equals(const Locale("fr", "FR")));
      expect(matchSupportedLocale("ES"), equals(const Locale("es", "ES")));
    });

    test("No Match", () async {
      expect(matchSupportedLocale(""), isNull);
      expect(matchSupportedLocale("   "), isNull);
      expect(matchSupportedLocale("xx"), isNull);
      expect(matchSupportedLocale("xx_YY"), isNull);
    });
  });
}
