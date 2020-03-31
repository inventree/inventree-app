import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;


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

  // Ensure we only ever create a single instance of the API class
  static final InvenTreeAPI _api = new InvenTreeAPI._internal();

  factory InvenTreeAPI() { return _api; }

  InvenTreeAPI._internal();

  void connect(String address, String username, String password) async {

    address = address.trim();
    username = username.trim();

    if (!address.endsWith("api/") || !address.endsWith("api")) {
      address = path.join(address, "api");
    }

    if (!address.endsWith('/')) {
      address = address + '/';
    }

    // TODO - Better URL validation

    /*
     * - If not a valid URL, return error
     * - If no port supplied, append a default port
     */

    _base_url = address;
    _username = username;
    _password = password;

    _connected = false;

    print("Connecting to " + address + " -> " + username + ":" + password);

    await _testConnection();

  }

  bool _connected = false;

  // Base URL for InvenTree API
  String _base_url = "http://127.0.0.1:8000/api/";

  String _username = "";
  String _password = "";

  // Authentication token (initially empty, must be requested)
  String _token = "";

  // Construct an API URL
  String _makeUrl(String url) {

    if (url.startsWith('/')) {
      url = url.substring(1);
    }



    return path.join(_base_url, url);
  }

  bool _hasToken() {
    return _token.isNotEmpty;
  }

  // Request the raw /api/ endpoint to see if there is an InvenTree server listening
  Future<void> _testConnection() async {

    print("Testing connection to server");

    await get("").then((http.Response response) {

      final data = json.decode(response.body);

      // We expect certain response from the server
      if (!data.containsKey("server") || !data.containsKey("version")) {
        print("Incorrect keys in server response");
      }

      print("Server: " + data["server"]);
      print("Version: " + data["version"]);

      // Ok, server is good. Request token!
      _getToken();

    }).catchError((error) {
      print("Error trying connection");
      print(error);
    });
  }

  // Request an API token from the server.
  // A valid username/password combination must be provided
  Future<String> _getToken() async {

    print("Requesting API token from server");

    if (_token.isNotEmpty) {
      print("Discarding old token - " + _token);
    }

    _token = "";

    var response = post(_URL_GET_TOKEN,
        body: {
          "username": _username,
          "password": _password,
        });

    response.then((http.Response response) {

      if (response.statusCode != 200) {
        print("Invalid status code: " + response.statusCode.toString());
        return false;
      } else {
        var data = json.decode(response.body);

        if (!data.containsKey("token")) {
          print("No token provided in response");
          return "";
        }

        // Return the received token
        String token = data["token"];
        print("Received token: " + token);

        return token;
      }
    }).catchError((error) {
      print("Error retrieving token:");
      print(error);
      return "";
    });
  }

  // Perform a PATCH request
  Future<http.Response> patch(String url, {Map<String, String> body}) async {

    var _url = _makeUrl(url);
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

    var _url = _makeUrl(url);
    var _headers = _defaultHeaders();
    var _body = Map<String, String>();

    // Copy across provided data
    body.forEach((K, V) => _body[K] = V);

    print("POST: " + _url);

    final response = await http.post(_url,
      headers: _headers,
      body: _body,
    );

    return response;
  }

  // Perform a GET request
  Future<http.Response> get(String url, {Map<String, String> params}) async {

    var _url = _makeUrl(url);
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