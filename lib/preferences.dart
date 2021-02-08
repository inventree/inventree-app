import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:path/path.dart';
import 'dart:async';


/*
 * Class for storing InvenTree preferences in a NoSql DB
 */
class InvenTreePreferencesDB {

  static final InvenTreePreferencesDB _singleton = InvenTreePreferencesDB._();

  static InvenTreePreferencesDB get instance => _singleton;

  InvenTreePreferencesDB._();

  Completer<Database> _dbOpenCompleter;

  Future<Database> get database async {
    // If completer is null, AppDatabaseClass is newly instantiated, so database is not yet opened
    if (_dbOpenCompleter == null) {
      _dbOpenCompleter = Completer();
      // Calling _openDatabase will also complete the completer with database instance
      _openDatabase();
    }
    // If the database is already opened, awaiting the future will happen instantly.
    // Otherwise, awaiting the returned future will take some time - until complete() is called
    // on the Completer in _openDatabase() below.
    return _dbOpenCompleter.future;
  }

  Future _openDatabase() async {
    // Get a platform-specific directory where persistent app data can be stored
    final appDocumentDir = await getApplicationDocumentsDirectory();

    print("Documents Dir: ${appDocumentDir.toString()}");

    print("Path: ${appDocumentDir.path}");

    // Path with the form: /platform-specific-directory/demo.db
    final dbPath = join(appDocumentDir.path, 'InvenTreeSettings.db');

    final database = await databaseFactoryIo.openDatabase(dbPath);

    // Any code awaiting the Completer's future will now start executing
    _dbOpenCompleter.complete(database);
  }
}

class InvenTreePreferences {

  static const String _SERVER = 'server';
  static const String _USERNAME = 'username';
  static const String _PASSWORD = 'password';

  /* The following settings are not stored to persistent storage,
   * instead they are only used as 'session preferences'.
   * They are kept here as a convenience only.
   */

  // Expand subcategory list in PartCategory view
  bool expandCategoryList = false;

  // Expand part list in PartCategory view
  bool expandPartList = true;

  // Expand sublocation list in StockLocation view
  bool expandLocationList = false;

  // Expand item list in StockLocation view
  bool expandStockList = true;

  // Ensure we only ever create a single instance of the preferences class
  static final InvenTreePreferences _api = new InvenTreePreferences._internal();

  factory InvenTreePreferences() {
    return _api;
  }

  InvenTreePreferences._internal();

  // Load saved login details, and attempt connection
  void loadLoginDetails(BuildContext context) async {

    print("Loading login details");

    await InvenTreeAPI().connectToServer(context);
  }

  void saveLoginDetails(BuildContext context, String server, String username, String password) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(_SERVER, server);
    await prefs.setString(_USERNAME, username);
    await prefs.setString(_PASSWORD, password);

    // Reconnect the API
    await InvenTreeAPI().connectToServer(context);
  }
}