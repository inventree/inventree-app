import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';


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
  void loadLoginDetails() async {

    print("Loading login details");

    SharedPreferences prefs = await SharedPreferences.getInstance();

    var server = prefs.getString(_SERVER) ?? '';
    var username = prefs.getString(_USERNAME) ?? '';
    var password = prefs.getString(_PASSWORD) ?? '';

    await InvenTreeAPI().connectToServer(server, username, password);
  }

  void saveLoginDetails(String server, String username, String password) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(_SERVER, server);
    await prefs.setString(_USERNAME, username);
    await prefs.setString(_PASSWORD, password);

    // Reconnect the API
    await InvenTreeAPI().connectToServer(server, username, password);
  }
}