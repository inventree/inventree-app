import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';


class InvenTreeUserPreferences {

  static const String _SERVER = 'server';
  static const String _USERNAME = 'username';
  static const String _PASSWORD = 'password';

  // Ensure we only ever create a single instance of the preferences class
  static final InvenTreeUserPreferences _api = new InvenTreeUserPreferences._internal();

  factory InvenTreeUserPreferences() {
    return _api;
  }

  InvenTreeUserPreferences._internal();

  // Load saved login details, and attempt connection
  void loadLoginDetails() async {

    print("Loading login details");

    SharedPreferences prefs = await SharedPreferences.getInstance();

    print("Done!");

    var server = prefs.getString(_SERVER) ?? '';
    var username = prefs.getString(_USERNAME) ?? '';
    var password = prefs.getString(_PASSWORD) ?? '';

    print("Connecting to server");

    await InvenTreeAPI().connect(server, username, password);
  }

  void saveLoginDetails(String server, String username, String password) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(_SERVER, server);
    await prefs.setString(_USERNAME, username);
    await prefs.setString(_PASSWORD, password);

    // Reconnect the API
    await InvenTreeAPI().connect(server, username, password);
  }
}