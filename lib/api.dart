import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  // Minimum supported InvenTree server version is 0.1.1
  static const List<int> MIN_SUPPORTED_VERSION = [0, 1, 1];

  bool _checkServerVersion(String version) {
    // TODO - Decode the provided version string and determine if the server is "new" enough
    return false;
  }

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
    return _makeUrl("/api/" + endpoint);
  }

  String makeUrl(String endpoint) {
    return _makeUrl(endpoint);
  }

  String _username = "";
  String _password = "";

  // Authentication token (initially empty, must be requested)
  String _token = "";

  bool isConnected() {
    return _token.isNotEmpty;
  }

  /*
   * Check server connection and display messages if not connected.
   * Useful as a precursor check before performing operations.
   */
  bool checkConnection(BuildContext context) {
    // Firstly, is the server connected?
    if (!isConnected()) {
      showDialog(
          context: context,
          child: new SimpleDialog(
              title: new Text("Not Connected"),
              children: <Widget>[
                ListTile(
                  title: Text("Server not connected"),
                )
              ]
          )
      );

      return false;
    }

    // Is the server version too old?
    // TODO

    // Finally
    return true;
  }

  // Server instance information
  String instance = '';

  // Server version information
  String _version = '';

  // Getter for server version information
  String get version => _version;

  // Connection status flag - set once connection has been validated
  bool _connected = false;

  bool get connected {
    return _connected && baseUrl.isNotEmpty && _token.isNotEmpty;
  }

  // Ensure we only ever create a single instance of the API class
  static final InvenTreeAPI _api = new InvenTreeAPI._internal();

  factory InvenTreeAPI() {
    return _api;
  }

  InvenTreeAPI._internal();

  Future<bool> connect() async {
    var prefs = await SharedPreferences.getInstance();

    String server = prefs.getString("server");
    String username = prefs.getString("username");
    String password = prefs.getString("password");

    return connectToServer(server, username, password);
  }

  Future<bool> connectToServer(String address, String username,
      String password) async {

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
        print("Could not connect to server");
        return null;
      } else if (error is TimeoutException) {
        print("Server timeout");
        return null;
      } else {
        // Unknown error type, re-throw error
        print("Unknown error: ${error.toString()}");
        throw error;
      }
    });

    if (response == null) {
      return false;
    }

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

    _version = data["version"];

    if (!_checkServerVersion(_version)) {
      // TODO - Something?
    }

    // Record the instance name of the server
    instance = data['instance'] ?? '';

    // Request token from the server if we do not already have one
    if (_token.isNotEmpty) {
      print("Already have token - $_token");
      return true;
    }

    // Clear out the token
    _token = "";

    response = await get(_URL_GET_TOKEN).timeout(Duration(seconds: 10)).catchError((error) {
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
    var _headers = defaultHeaders();
    var _body = Map<String, String>();

    // Copy across provided data
    body.forEach((K, V) => _body[K] = V);

    print("PATCH: " + _url);

    return http.patch(_url,
      headers: _headers,
      body: _body,
    );
  }

  /*
   * Upload a file to the given URL
   */
  Future<http.StreamedResponse> uploadFile(String url, File f,
      {String name = "attachment", Map<String, String> fields}) async {
    var _url = makeApiUrl(url);

    var request = http.MultipartRequest('POST', Uri.parse(_url));

    request.headers.addAll(defaultHeaders());

    fields.forEach((String key, String value) {
      request.fields[key] = value;
    });

    var _file = await http.MultipartFile.fromPath(name, f.path);

    request.files.add(_file);

    var response = await request.send();

    return response;
  }

  // Perform a POST request
  Future<http.Response> post(String url, {Map<String, dynamic> body}) async {
    var _url = makeApiUrl(url);
    var _headers = jsonHeaders();

    print("POST: ${_url} -> ${body.toString()}");

    var data = jsonEncode(body);

    return http.post(_url,
      headers: _headers,
      body: data,
    );
  }

  // Perform a GET request
  Future<http.Response> get(String url, {Map<String, String> params}) async {
    var _url = makeApiUrl(url);
    var _headers = defaultHeaders();

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

  Map<String, String> defaultHeaders() {
    var headers = Map<String, String>();

    headers[HttpHeaders.authorizationHeader] = _authorizationHeader();

    return headers;
  }

  Map<String, String> jsonHeaders() {
    var headers = defaultHeaders();
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  String _authorizationHeader() {
    if (_token.isNotEmpty) {
      return "Token $_token";
    } else {
      return "Basic " + base64Encode(utf8.encode('$_username:$_password'));
    }
  }

  static String get staticImage => "/static/img/blank_image.png";

  static String get staticThumb => "/static/img/blank_image.thumbnail.png";

  /**
   * Load image from the InvenTree server,
   * or from local cache (if it has been cached!)
   */
  CachedNetworkImage getImage(String imageUrl, {double height, double width}) {
    if (imageUrl.isEmpty) {
      imageUrl = staticImage;
    }

    String url = makeUrl(imageUrl);

    return new CachedNetworkImage(
      imageUrl: url,
      placeholder: (context, url) => CircularProgressIndicator(),
      errorWidget: (context, url, error) => Icon(FontAwesomeIcons.exclamation),
      httpHeaders: defaultHeaders(),
      height: height,
      width: width,
    );
  }
}