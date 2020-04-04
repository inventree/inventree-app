import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


/**
 * InvenTree API - Access to the InvenTree REST interface.
 *
 * InvenTree implements token-based authentication, which is
 * initialised using a username:password combination.
 */


class InvenTreeAPI {

  // Endpoint for requesting an API token
  static const _URL_GET_TOKEN = "user/token/";
  static const _URL_GET_VERSION = "";

  // Base URL for InvenTree API e.g. http://192.168.120.10:8000
  String _BASE_URL = "";

  // Accessors for various url endpoints
  String get baseUrl {
    String url = _BASE_URL;

    if (!url.endsWith("/")) {
      url += "/";
    }

    return url;
  }

  String _makeUrl(String url) {
    if (url.startsWith('/')) {
      url = url.substring(1, url.length);
    }

    url = url.replaceAll('//', '/');

    return baseUrl + url;
  }

  String get apiUrl {
    return _makeUrl("/api/");
  }

  String get imageUrl {
    return _makeUrl("/image/");
  }

  String makeApiUrl(String endpoint) {

    return apiUrl + endpoint;
  }

  String makeUrl(String endpoint) {
    return _makeUrl(endpoint);
  }

  String _username = "";
  String _password = "";

  // Authentication token (initially empty, must be requested)
  String _token = "";

  // Connection status flag - set once connection has been validated
  bool _connected = false;

  bool get connected {
    return _connected && baseUrl.isNotEmpty && _token.isNotEmpty;
  }

  // Ensure we only ever create a single instance of the API class
  static final InvenTreeAPI _api = new InvenTreeAPI._internal();

  factory InvenTreeAPI() { return _api; }

  InvenTreeAPI._internal();

  void disconnected() {
    _connected = false;

    // Clear token
    _token = "";
  }

  Future<bool> connect() async {

    var prefs = await SharedPreferences.getInstance();

    String server = prefs.getString("server");
    String username = prefs.getString("username");
    String password = prefs.getString("password");

    return connectToServer(server, username, password);
  }

  Future<bool> connectToServer(String address, String username, String password) async {

    /* Address is the base address for the InvenTree server,
     * e.g. http://127.0.0.1:8000
     */

    String errorMessage = "";

    address = address.trim();
    username = username.trim();

    if (address.isEmpty || username.isEmpty || password.isEmpty) {
      errorMessage = "Server Error: Empty details supplied";
      print(errorMessage);
      throw errorMessage;
    }

    if (!address.endsWith('/')) {
      address = address + '/';
    }

    // TODO - Better URL validation

    /*
     * - If not a valid URL, return error
     * - If no port supplied, append a default port
     */

    _BASE_URL = address;
    _username = username;
    _password = password;

    _connected = false;

    print("Connecting to " + apiUrl + " -> " + username + ":" + password);

    // TODO - Add connection timeout

    var response = await get("").timeout(Duration(seconds: 10)).catchError((error) {

      if (error is SocketException) {
        errorMessage = "Could not connect to server.";
        print(errorMessage);
        throw errorMessage;
      } else {
        // Unknown error type, re-throw error
        throw error;
      }
    });

    if (response.statusCode != 200) {
      print("Invalid status code: " + response.statusCode.toString());
      return false;
    }

    var data = json.decode(response.body);

    print("Response from server: $data");

    // We expect certain response from the server
    if (!data.containsKey("server") || !data.containsKey("version")) {
      errorMessage = "Server resonse contained incorrect data";
      print(errorMessage);
      throw errorMessage;
    }

    print("Server: " + data["server"]);
    print("Version: " + data["version"]);

    // Request token from the server if we do not already have one
    if (_token.isNotEmpty) {
      print("Already have token - $_token");
      return true;
    }

    // Clear out the token
    _token = "";

    response = await post(_URL_GET_TOKEN, body: {"username": _username, "password": _password}).catchError((error) {
      print("Error requesting token:");
      print(error);
      return false;
    });

    if (response.statusCode != 200) {
      print("Invalid status code: " + response.statusCode.toString());
      return false;
    } else {
      var data = json.decode(response.body);

      if (!data.containsKey("token")) {
        print("No token provided in response");
        return false;
      }

      // Return the received token
      _token = data["token"];
      print("Received token - $_token");

      _connected = true;

      return true;
    };
  }

  // Perform a PATCH request
  Future<http.Response> patch(String url, {Map<String, String> body}) async {

    var _url = makeApiUrl(url);
    var _headers = _defaultHeaders();
    var _body = Map<String, String>();

    // Copy across provided data
    body.forEach((K, V) => _body[K] = V);

    print("PATCH: " + _url);

    final response = await http.patch(_url,
      headers: _headers,
      body: _body,
    );

    return response;
  }

  // Perform a POST request
  Future<http.Response> post(String url, {Map<String, String> body}) async {

    var _url = makeApiUrl(url);
    var _headers = _defaultHeaders();
    var _body = Map<String, String>();

    // Copy across provided data
    body.forEach((K, V) => _body[K] = V);

    print("POST: " + _url);

    return http.post(_url,
      headers: _headers,
      body: _body,
    );
  }

  // Perform a GET request
  Future<http.Response> get(String url, {Map<String, String> params}) async {

    var _url = makeApiUrl(url);
    var _headers = _defaultHeaders();

    // If query parameters are supplied, form a query string
    if (params != null && params.isNotEmpty) {
      String query = '?';

      params.forEach((K, V) => query += K + '=' + V + '&');

      _url += query;
    }

    // Remove extraneous character if present
    if (_url.endsWith('&')) {
      _url = _url.substring(0, _url.length - 1);
    }

    print("GET: " + _url);

    return http.get(_url, headers: _headers);
  }

  Map<String, String> _defaultHeaders() {

    var headers = Map<String, String>();

    // Preference authentication token if available
    if (_token.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = "Token " + _token;
    } else {
      headers[HttpHeaders.authorizationHeader] = 'Basic ' + base64Encode(utf8.encode('$_username:$_password'));
    }

    return headers;
  }

}