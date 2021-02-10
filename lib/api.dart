import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:InvenTree/user_profile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:InvenTree/widget/dialogs.dart';

import 'package:http/http.dart' as http;


/**
 * InvenTree API - Access to the InvenTree REST interface.
 *
 * InvenTree implements token-based authentication, which is
 * initialised using a username:password combination.
 */


class InvenTreeAPI {

  // Minimum supported InvenTree server version is
  static const List<int> MIN_SUPPORTED_VERSION = [0, 1, 5];

  String get _requiredVersionString => "${MIN_SUPPORTED_VERSION[0]}.${MIN_SUPPORTED_VERSION[1]}.${MIN_SUPPORTED_VERSION[2]}";

  bool _checkServerVersion(String version) {

    // Provided version string should be of the format "x.y.z [...]"
    List<String> versionSplit = version.split(' ').first.split('.');

    // Extract the version number <major>.<minor>.<sub> from the string
    if (versionSplit.length != 3) {
      return false;
    }

    // Cast the server version to an explicit integer
    int server_version_code = 0;

    print("server version: ${version}");

    server_version_code += (int.tryParse(versionSplit[0]) ?? 0) * 100 * 100;
    server_version_code += (int.tryParse(versionSplit[1]) ?? 0) * 100;
    server_version_code += (int.tryParse(versionSplit[2]));

    print("server version code: ${server_version_code}");

    int required_version_code = 0;

    required_version_code += MIN_SUPPORTED_VERSION[0] * 100 * 100;
    required_version_code += MIN_SUPPORTED_VERSION[1] * 100;
    required_version_code += MIN_SUPPORTED_VERSION[2];

    print("required version code: ${required_version_code}");

    return server_version_code >= required_version_code;
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

  String get apiUrl => _makeUrl("/api/");

  String get imageUrl => _makeUrl("/image/");

  String makeApiUrl(String endpoint) => _makeUrl("/api/" + endpoint);

  String makeUrl(String endpoint) => _makeUrl(endpoint);

  UserProfile profile;

  // Authentication token (initially empty, must be requested)
  String _token = "";

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
              title: new Text(I18N.of(context).notConnected),
              children: <Widget>[
                ListTile(
                  title: Text(I18N.of(context).serverNotConnected),
                )
              ]
          )
      );

      return false;
    }

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

  bool _connecting = false;

  bool isConnected() {
    return profile != null && _connected && baseUrl.isNotEmpty && _token.isNotEmpty;
  }

  bool isConnecting() {
    return !isConnected() && _connecting;
  }

  // Ensure we only ever create a single instance of the API class
  static final InvenTreeAPI _api = new InvenTreeAPI._internal();

  factory InvenTreeAPI() {
    return _api;
  }

  InvenTreeAPI._internal();

  Future<bool> _connect(BuildContext context) async {

    /* Address is the base address for the InvenTree server,
     * e.g. http://127.0.0.1:8000
     */

    if (profile == null) return false;

    String address = profile.server.trim();
    String username = profile.username.trim();
    String password = profile.password.trim();

    if (address.isEmpty || username.isEmpty || password.isEmpty) {
      await showErrorDialog(
        context,
        I18N.of(context).error,
        "Incomplete server details",
        icon: FontAwesomeIcons.server
      );

      return false;
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

    print("Connecting to ${apiUrl} -> ${username}:${password}");

    var response = await get("").timeout(Duration(seconds: 10)).catchError((error) {

      print("Error connecting to server: ${error.toString()}");

      if (error is SocketException) {
        showServerError(
            context,
            I18N.of(context).connectionRefused,
            error.toString());
        return null;
      } else if (error is TimeoutException) {
        showTimeoutError(context);
        return null;
      } else {
        // Unknown error type - re-throw the error and Sentry will catch it
        throw error;
      }
    });

    if (response == null) {
      // Null (or error) response: Show dialog and exit
      return false;
    }

    if (response.statusCode != 200) {
      // Any status code other than 200!

      showStatusCodeError(context, response.statusCode);

      // TODO: Interpret the error codes and show custom message?
      return false;
    }

    var data = json.decode(response.body);

    print("Response from server: $data");

    // We expect certain response from the server
    if (!data.containsKey("server") || !data.containsKey("version") || !data.containsKey("instance")) {

      showServerError(
        context,
        "Missing Data",
        "Server response missing required fields"
      );

      return false;
    }

    // Record server information
    _version = data["version"];
    instance = data['instance'] ?? '';

    // Check that the remote server version is *new* enough
    if (!_checkServerVersion(_version)) {
      showServerError(
          context,
          "Old Server Version",
          "\n\nServer Version: ${_version}\n\nRequired version: ${_requiredVersionString}"
      );

      return false;
    }

    // Clear the existing token value
    _token = "";

    print("Requesting token from server");

    response = await get(_URL_GET_TOKEN).timeout(Duration(seconds: 10)).catchError((error) {

      print("Error requesting token:");
      print(error);

    });

    if (response == null) {
      showServerError(
          context, "Token Error", "Error requesting access token from server"
      );

      return false;
    }

    if (response.statusCode != 200) {
      showStatusCodeError(context, response.statusCode);
      return false;
    } else {
      var data = json.decode(response.body);

      if (!data.containsKey("token")) {
        showServerError(
          context,
          "Missing Token",
          "Access token missing from response"
        );

        return false;
      }

      // Return the received token
      _token = data["token"];
      print("Received token - $_token");

      _connected = true;

      // Ok, probably pretty good...
      return true;
    };
  }

  bool disconnectFromServer() {
    print("InvenTreeAPI().disconnectFromServer()");

    _connected = false;
    _connecting = false;
    _token = '';
    profile = null;
  }

  Future<bool> connectToServer(BuildContext context) async {

    // Ensure server is first disconnected
    disconnectFromServer();

    // Load selected profile
    profile = await UserProfileDBManager().getSelectedProfile();

    print("API Profile: ${profile.toString()}");

    if (profile == null) {
      await showErrorDialog(
          context,
          "Select Profile",
          "User profile not selected"
      );
      return false;
    }

    _connecting = true;

    bool result = await _connect(context);

    print("_connect() returned result: ${result}");

    _connecting = false;

    return result;
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

    if (profile != null) {
      headers[HttpHeaders.authorizationHeader] = _authorizationHeader(profile.username, profile.password);
    }

    return headers;
  }

  Map<String, String> jsonHeaders() {
    var headers = defaultHeaders();
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  String _authorizationHeader(String username, String password) {
    if (_token.isNotEmpty) {
      return "Token $_token";
    } else {
      return "Basic " + base64Encode(utf8.encode('${username}:${password}'));
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