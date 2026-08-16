import "dart:io";
import "dart:ui";

import "package:adaptive_theme/adaptive_theme.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:inventree/l10n/supported_locales.dart";
import "package:inventree/preferences.dart";
import "package:inventree/user_profile.dart";

const String MANAGED_CONFIG_SERVER_KEY = "server";
const String MANAGED_CONFIG_NAME_KEY = "name";
const String MANAGED_CONFIG_TOKEN_KEY = "token";

const String MANAGED_CONFIG_THEME_KEY = "themeMode";
const String MANAGED_CONFIG_LANGUAGE_KEY = "language";

const String _MANAGED_CONFIG_APPLIED_KEY = "managedConfigApplied";
const String _MANAGED_SETTINGS_APPLIED_KEY = "managedSettingsApplied";

const String INV_MANAGED_THEME_MODE = "managedThemeMode";

const MethodChannel _channel = MethodChannel("inventree/managed_config");

enum ManagedSettingType { boolean, integer, choice }

class ManagedSetting {
  const ManagedSetting(
    this.key,
    this.type, {
    this.choices = const {},
    this.minimum,
    this.maximum,
  });

  final String key;

  final ManagedSettingType type;

  final Map<String, int> choices;

  final int? minimum;
  final int? maximum;

  dynamic parse(dynamic raw) {
    if (raw == null) return null;

    switch (type) {
      case ManagedSettingType.boolean:
        return _parseBool(raw);
      case ManagedSettingType.integer:
        return _parseInt(raw);
      case ManagedSettingType.choice:
        return _parseChoice(raw);
    }
  }

  bool? _parseBool(dynamic raw) {
    if (raw is bool) return raw;

    switch (raw.toString().trim().toLowerCase()) {
      case "true":
      case "1":
      case "yes":
      case "on":
        return true;
      case "false":
      case "0":
      case "no":
      case "off":
        return false;
      default:
        return null;
    }
  }

  int? _parseInt(dynamic raw) {
    int? value;

    if (raw is int) {
      value = raw;
    } else if (raw is num) {
      value = raw.toInt();
    } else {
      value = int.tryParse(raw.toString().trim());
    }

    if (value == null) return null;

    final int? min = minimum;
    final int? max = maximum;

    if (min != null && value < min) value = min;
    if (max != null && value > max) value = max;

    return value;
  }

  int? _parseChoice(dynamic raw) {
    final String name = raw.toString().trim().toLowerCase();

    for (final entry in choices.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }

    final int? value = raw is int ? raw : int.tryParse(name);

    if (value != null && choices.containsValue(value)) {
      return value;
    }

    return null;
  }
}

const List<ManagedSetting> MANAGED_SETTINGS = [
  // App settings
  ManagedSetting(
    INV_SCREEN_ORIENTATION,
    ManagedSettingType.choice,
    choices: {
      "system": SCREEN_ORIENTATION_SYSTEM,
      "portrait": SCREEN_ORIENTATION_PORTRAIT,
      "landscape": SCREEN_ORIENTATION_LANDSCAPE,
    },
  ),
  ManagedSetting(INV_ENABLE_LABEL_PRINTING, ManagedSettingType.boolean),
  ManagedSetting(INV_STRICT_HTTPS, ManagedSettingType.boolean),
  ManagedSetting(INV_REPORT_ERRORS, ManagedSettingType.boolean),
  ManagedSetting(INV_SOUNDS_BARCODE, ManagedSettingType.boolean),
  ManagedSetting(INV_SOUNDS_SERVER, ManagedSettingType.boolean),
  ManagedSetting(INV_SHOW_PK, ManagedSettingType.boolean),

  // Home Screen settings
  ManagedSetting(INV_HOME_SHOW_SUBSCRIBED, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_PO, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_SO, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_SHIPMENTS, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_BUILD, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_MANUFACTURERS, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_CUSTOMERS, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_SUPPLIERS, ManagedSettingType.boolean),
  ManagedSetting(INV_HOME_SHOW_TRANSFER, ManagedSettingType.boolean),

  // Barcode settings
  ManagedSetting(
    INV_BARCODE_SCAN_TYPE,
    ManagedSettingType.choice,
    choices: {
      "camera": BARCODE_CONTROLLER_CAMERA,
      "wedge": BARCODE_CONTROLLER_WEDGE,
      "intent": BARCODE_CONTROLLER_INTENT,
    },
  ),
  ManagedSetting(
    INV_BARCODE_SCAN_DELAY,
    ManagedSettingType.integer,
    minimum: 100,
    maximum: 2500,
  ),
  ManagedSetting(INV_BARCODE_SCAN_SINGLE, ManagedSettingType.boolean),

  // Part settings
  ManagedSetting(INV_PART_SHOW_BOM, ManagedSettingType.boolean),
  ManagedSetting(INV_PART_SHOW_PRICING, ManagedSettingType.boolean),
  ManagedSetting(INV_PART_SHOW_REQUIREMENTS, ManagedSettingType.boolean),

  // Stock settings
  ManagedSetting(INV_STOCK_SHOW_HISTORY, ManagedSettingType.boolean),
  ManagedSetting(INV_STOCK_SHOW_TESTS, ManagedSettingType.boolean),
  ManagedSetting(INV_STOCK_CONFIRM_SCAN, ManagedSettingType.boolean),

  // Purchase Order settings
  ManagedSetting(INV_PO_ENABLE, ManagedSettingType.boolean),
  ManagedSetting(INV_PO_SHOW_CAMERA, ManagedSettingType.boolean),
  ManagedSetting(INV_PO_CONFIRM_SCAN, ManagedSettingType.boolean),

  // Sales Order settings
  ManagedSetting(INV_SO_ENABLE, ManagedSettingType.boolean),
  ManagedSetting(INV_SO_SHOW_CAMERA, ManagedSettingType.boolean),
];

const Map<String, AdaptiveThemeMode> MANAGED_THEME_MODES = {
  "system": AdaptiveThemeMode.system,
  "light": AdaptiveThemeMode.light,
  "dark": AdaptiveThemeMode.dark,
};

Future<void> initManagedConfiguration() async {
  if (kIsWeb || !Platform.isAndroid) return;

  Map<String, dynamic>? config;

  try {
    config = await _channel.invokeMapMethod<String, dynamic>(
      "getManagedConfiguration",
    );
  } catch (error) {
    return;
  }

  await applyManagedConfiguration(config);
}

Future<void> applyManagedConfiguration(Map<String, dynamic>? config) async {
  if (config == null || config.isEmpty) return;

  await _applyManagedProfile(config);
  await _applyManagedSettings(config);
}

Future<void> _applyManagedProfile(Map<String, dynamic> config) async {
  final String server = (config[MANAGED_CONFIG_SERVER_KEY] ?? "")
      .toString()
      .trim();

  // Server address is required
  if (server.isEmpty) return;

  String name = (config[MANAGED_CONFIG_NAME_KEY] ?? "").toString().trim();

  // Profile name is required
  if (name.isEmpty) return;

  final String token = (config[MANAGED_CONFIG_TOKEN_KEY] ?? "")
      .toString()
      .trim();

  final String fingerprint = "${name}|${server}";

  final String applied =
      await InvenTreeSettingsManager().getValue(_MANAGED_CONFIG_APPLIED_KEY, "")
          as String;

  final manager = UserProfileDBManager();

  UserProfile? profile = await manager.getProfileByName(name);

  // Compare token against stored token
  final bool tokenChanged = token.isNotEmpty && profile?.token != token;

  // Check if anything actually changed
  if (applied == fingerprint && !tokenChanged) return;

  // No demo profile
  await InvenTreeSettingsManager().setValue("demo_profile_added", true);

  if (profile == null) {
    profile = UserProfile(name: name, server: server, token: token);

    await manager.addProfile(profile);
  } else {
    profile.server = server;

    if (token.isNotEmpty) profile.token = token;

    await manager.updateProfile(profile);
  }

  // Select the profile
  await manager.selectProfileByName(name);

  await InvenTreeSettingsManager().setValue(
    _MANAGED_CONFIG_APPLIED_KEY,
    fingerprint,
  );
}

Future<void> _applyManagedSettings(Map<String, dynamic> config) async {
  final Map<String, dynamic> values = {};

  for (final setting in MANAGED_SETTINGS) {
    if (!config.containsKey(setting.key)) continue;

    final dynamic value = setting.parse(config[setting.key]);

    if (value == null) continue;

    values[setting.key] = value;
  }

  AdaptiveThemeMode? themeMode;

  if (config.containsKey(MANAGED_CONFIG_THEME_KEY)) {
    final String mode = config[MANAGED_CONFIG_THEME_KEY]
        .toString()
        .trim()
        .toLowerCase();

    themeMode = MANAGED_THEME_MODES[mode];
  }

  bool applyLocale = false;
  Locale? locale;

  if (config.containsKey(MANAGED_CONFIG_LANGUAGE_KEY)) {
    final String language = config[MANAGED_CONFIG_LANGUAGE_KEY]
        .toString()
        .trim();

    if (language.isEmpty) {
      applyLocale = true;
    } else {
      locale = matchSupportedLocale(language);

      if (locale != null) applyLocale = true;
    }
  }

  if (values.isEmpty && themeMode == null && !applyLocale) return;

  final List<String> elements = values.keys.toList()..sort();

  final String fingerprint = [
    ...elements.map((key) => "${key}=${values[key]}"),
    if (themeMode != null) "${MANAGED_CONFIG_THEME_KEY}=${themeMode.name}",
    if (applyLocale)
      "${MANAGED_CONFIG_LANGUAGE_KEY}=${locale?.toString() ?? ""}",
  ].join("|");

  final String applied =
      await InvenTreeSettingsManager().getValue(
            _MANAGED_SETTINGS_APPLIED_KEY,
            "",
          )
          as String;

  if (applied == fingerprint) return;

  for (final entry in values.entries) {
    await InvenTreeSettingsManager().setValue(entry.key, entry.value);
  }

  if (themeMode != null) {
    await InvenTreeSettingsManager().setValue(
      INV_MANAGED_THEME_MODE,
      themeMode.name,
    );
  }

  if (applyLocale) {
    await InvenTreeSettingsManager().setSelectedLocale(locale);
  }

  await InvenTreeSettingsManager().setValue(
    _MANAGED_SETTINGS_APPLIED_KEY,
    fingerprint,
  );
}

Locale? matchSupportedLocale(String name) {
  final String value = name.trim().replaceAll("-", "_");

  if (value.isEmpty) return null;

  for (final locale in supported_locales) {
    if (locale.toString().toLowerCase() == value.toLowerCase()) return locale;
  }

  for (final locale in supported_locales) {
    if (locale.languageCode.toLowerCase() == value.toLowerCase()) return locale;
  }

  return null;
}

Future<AdaptiveThemeMode?> getPendingManagedThemeMode() async {
  final String mode =
      await InvenTreeSettingsManager().getValue(INV_MANAGED_THEME_MODE, "")
          as String;

  if (mode.isEmpty) return null;

  return MANAGED_THEME_MODES[mode.toLowerCase()];
}

Future<void> clearPendingManagedThemeMode() async {
  await InvenTreeSettingsManager().setValue(INV_MANAGED_THEME_MODE, "");
}
