/*
 * Class for managing app-level configuration options
 */

import "package:sembast/sembast.dart";
import "package:inventree/preferences.dart";

// Settings key values
const String INV_HOME_SHOW_SUBSCRIBED = "homeShowSubscribed";
const String INV_HOME_SHOW_PO = "homeShowPo";
const String INV_HOME_SHOW_MANUFACTURERS = "homeShowManufacturers";
const String INV_HOME_SHOW_CUSTOMERS = "homeShowCustomers";
const String INV_HOME_SHOW_SUPPLIERS = "homeShowSuppliers";

const String INV_SOUNDS_BARCODE = "barcodeSounds";
const String INV_SOUNDS_SERVER = "serverSounds";

const String INV_PART_SUBCATEGORY = "partSubcategory";

const String INV_STOCK_SUBLOCATION = "stockSublocation";


class InvenTreeSettingsManager {

  factory InvenTreeSettingsManager() {
    return _manager;
  }

  InvenTreeSettingsManager._internal();

  final store = StoreRef("settings");

  Future<Database> get _db async => InvenTreePreferencesDB.instance.database;

  Future<dynamic> getValue(String key, dynamic backup) async {

    final value = await store.record(key).get(await _db);

    if (value == null) {
      return backup;
    }

    return value;
  }

  // Load a boolean setting
  Future<bool> getBool(String key, bool backup) async {
    final dynamic value = await getValue(key, backup);

    if (value is bool) {
      return value;
    } else {
      return backup;
    }
  }

  Future<void> setValue(String key, dynamic value) async {

    await store.record(key).put(await _db, value);
  }

  // Ensure we only ever create a single instance of this class
  static final InvenTreeSettingsManager _manager = InvenTreeSettingsManager._internal();
}
