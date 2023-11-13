import "dart:async";
import "dart:ui";

import "package:inventree/l10n/supported_locales.dart";
import "package:path_provider/path_provider.dart";
import "package:sembast/sembast.dart";
import "package:sembast/sembast_io.dart";
import "package:path/path.dart";


// Settings key values
const String INV_HOME_SHOW_SUBSCRIBED = "homeShowSubscribed";
const String INV_HOME_SHOW_PO = "homeShowPo";
const String INV_HOME_SHOW_SO = "homeShowSo";
const String INV_HOME_SHOW_MANUFACTURERS = "homeShowManufacturers";
const String INV_HOME_SHOW_CUSTOMERS = "homeShowCustomers";
const String INV_HOME_SHOW_SUPPLIERS = "homeShowSuppliers";

const String INV_SCREEN_ORIENTATION = "appScreenOrientation";

// Available screen orientation values
const int SCREEN_ORIENTATION_SYSTEM = 0;
const int SCREEN_ORIENTATION_PORTRAIT = 1;
const int SCREEN_ORIENTATION_LANDSCAPE = 2;

const String INV_SOUNDS_BARCODE = "barcodeSounds";
const String INV_SOUNDS_SERVER = "serverSounds";

const String INV_ENABLE_LABEL_PRINTING = "enableLabelPrinting";

// Part settings
const String INV_PART_SHOW_PARAMETERS = "partShowParameters";
const String INV_PART_SHOW_BOM = "partShowBom";

// Stock settings
const String INV_STOCK_SHOW_HISTORY = "stockShowHistory";
const String INV_STOCK_SHOW_TESTS = "stockShowTests";

const String INV_REPORT_ERRORS = "reportErrors";
const String INV_STRICT_HTTPS = "strictHttps";

// Barcode settings
const String INV_BARCODE_SCAN_DELAY = "barcodeScanDelay";
const String INV_BARCODE_SCAN_TYPE = "barcodeScanType";
const String INV_BARCODE_SCAN_SINGLE = "barcodeScanSingle";

// Barcode scanner types
const int BARCODE_CONTROLLER_CAMERA = 0;
const int BARCODE_CONTROLLER_WEDGE = 1;

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

    // Path with the form: /platform-specific-directory/demo.db
    final dbPath = join(appDocumentDir.path, "InvenTreeSettings.db");

    final database = await databaseFactoryIo.openDatabase(dbPath);

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

  Future<Locale?> getSelectedLocale() async {
    final String locale_name = await getValue("customLocale", "") as String;

    if (locale_name.isEmpty) {
      return null;
    }

    for (var locale in supported_locales) {
      if (locale.toString() == locale_name) {
        return locale;
      }
    }

    // No matching locale found
    return null;
  }

  Future<void> setSelectedLocale(Locale? locale) async {
    await setValue("customLocale", locale?.toString() ?? "");
  }

  Future<void> removeValue(String key) async {
    await store.record(key).delete(await _db);
  }

  Future<dynamic> getValue(String key, dynamic backup) async {

    dynamic value = await store.record(key).get(await _db);

    // Retrieve value
    if (value == "__null__") {
      value = null;
    }

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
    } else if (value is String) {
      return value.toLowerCase().contains("t");
    } else {
      return false;
    }
  }

  // Store a key:value pair in the database
  Future<void> setValue(String key, dynamic value) async {

    // Encode null values as strings
    value ??= "__null__";

    await store.record(key).put(await _db, value);
  }

  // Ensure we only ever create a single instance of this class
  static final InvenTreeSettingsManager _manager = InvenTreeSettingsManager._internal();
}
