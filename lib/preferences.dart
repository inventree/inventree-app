import "dart:async";

import "package:path_provider/path_provider.dart";
import "package:sembast/sembast.dart";
import "package:sembast/sembast_io.dart";
import "package:path/path.dart";


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
const String INV_STOCK_SHOW_HISTORY = "stockShowHistory";

const String INV_REPORT_ERRORS = "reportErrors";

const String INV_STRICT_HTTPS = "strictHttps";


/*
 * Class for storing InvenTree preferences in a NoSql DB
 */
class InvenTreePreferencesDB {

  InvenTreePreferencesDB._();

  static final InvenTreePreferencesDB _singleton = InvenTreePreferencesDB._();

  static InvenTreePreferencesDB get instance => _singleton;

  Completer<Database> _dbOpenCompleter = Completer();

  bool isOpen = false;

  Future<Database> get database async {

    if (!isOpen) {
      // Calling _openDatabase will also complete the completer with database instance
      _openDatabase();

      isOpen = true;
    }

    // If the database is already opened, awaiting the future will happen instantly.
    // Otherwise, awaiting the returned future will take some time - until complete() is called
    // on the Completer in _openDatabase() below.
    return _dbOpenCompleter.future;
  }

  Future<void> _openDatabase() async {
    // Get a platform-specific directory where persistent app data can be stored
    final appDocumentDir = await getApplicationDocumentsDirectory();

    print("Documents Dir: ${appDocumentDir.toString()}");

    print("Path: ${appDocumentDir.path}");

    // Path with the form: /platform-specific-directory/demo.db
    final dbPath = join(appDocumentDir.path, "InvenTreeSettings.db");

    final database = await databaseFactoryIo.openDatabase(dbPath);

    // Any code awaiting the Completer's future will now start executing
    _dbOpenCompleter.complete(database);
  }
}


/*
 * InvenTree setings manager class.
 * Provides functions for loading and saving settings, with provision for default values
 */
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
