/*
 * Class for managing app-level configuration options
 */

import 'package:sembast/sembast.dart';
import 'package:InvenTree/preferences.dart';

class InvenTreeSettingsManager {

  final store = StoreRef("settings");

  Future<Database> get _db async => await InvenTreePreferencesDB.instance.database;

  Future<dynamic> getValue(String key, dynamic backup) async {

    final value = await store.record(key).get(await _db);

    if (value == null) {
      return backup;
    }

    return value;
  }

  Future<void> setValue(String key, dynamic value) async {

    await store.record(key).put(await _db, value);
  }

  // Ensure we only ever create a single instance of this class
  static final InvenTreeSettingsManager _manager = new InvenTreeSettingsManager._internal();

  factory InvenTreeSettingsManager() {
    return _manager;
  }

  InvenTreeSettingsManager._internal();
}