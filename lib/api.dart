import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:InvenTree/user_profile.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:InvenTree/widget/dialogs.dart';

import 'package:http/http.dart' as http;
import 'package:one_context/one_context.dart';


/**
 * InvenTree API - Access to the InvenTree REST interface.
 *
 * InvenTree implements token-based authentication, which is
 * initialised using a username:password combination.
 */


class InvenTreeAPI {

  // Minimum required API version for server
  static const _minApiVersion = 2;

  // Endpoint for requesting an API token
  static const _URL_GET_TOKEN = "user/token/";
  static const _URL_GET_VERSION = "";

  static const _URL_GET_ROLES = "user/roles/";

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

  Map<String, dynamic> roles = {};

  // Authentication token (initially empty, must be requested)
  String _token = "";

  /*
   * Check server connection and display messages if not connected.
   * Useful as a precursor check before performing operations.
   */
  bool checkConnection(BuildContext context) {
    // Firstly, is the server connected?
    if (!isConnected()) {

      showSnackIcon(
        I18N.of(context).notConnected,
        success: false,
        icon: FontAwesomeIcons.server
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

  // API version of the connected server
  int _apiVersion = 1;

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
      showSnackIcon(
        "Incomplete server details",
        icon: FontAwesomeIcons.exclamationCircle,
        success: false
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

    // Request the /api/ endpoint - response is a json object
    var response = await get("");

    // Null response means something went horribly wrong!
    if (response == null) {
      return false;
    }


    print("Response from server: ${response}");

    // We expect certain response from the server
    if (!response.containsKey("server") || !response.containsKey("version") || !response.containsKey("instance")) {

      showServerError(
        "Missing Data",
        "Server response missing required fields"
      );

      return false;
    }

    // Record server information
    _version = response["version"];
    instance = response['instance'] ?? '';

    // Default API version is 1 if not provided
    _apiVersion = response['apiVersion'] as int ?? 1;

    if (_apiVersion < _minApiVersion) {

      BuildContext ctx = OneContext().context;

      String message = I18N.of(ctx).serverApiVersion + ": ${_apiVersion}";

      message += "\n";
      message += I18N.of(ctx).serverApiRequired + ": ${_minApiVersion}";

      message += "\n\n";

      message += "Ensure your InvenTree server version is up to date!";

      showServerError(
        I18N.of(OneContext().context).serverOld,
        message
      );

      return false;
    }

    // Clear the existing token value
    _token = "";

    print("Requesting token from server");

    response = await get(_URL_GET_TOKEN);

    if (response == null) {
      showServerError(
          I18N.of(OneContext().context).tokenError,
          "Error requesting access token from server"
      );

      return false;
    }

    if (!response.containsKey("token")) {
      showServerError(
          I18N.of(OneContext().context).tokenMissing,
          "Access token missing from response"
      );

      return false;
    }

    // Return the received token
    _token = response["token"];
    print("Received token - $_token");

    // Request user role information
    await getUserRoles();

    // Ok, probably pretty good...
    return true;

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
      showSnackIcon(
          I18N.of(OneContext().context).profileSelect,
          success: false,
          icon: FontAwesomeIcons.exclamationCircle
      );
      return false;
    }

    _connecting = true;

    _connected = await _connect(context);

    print("_connect() returned result: ${_connected}");

    _connecting = false;

    if (_connected) {
      showSnackIcon(
        I18N.of(OneContext().context).serverConnected,
        icon: FontAwesomeIcons.server,
        success: true,
      );
    }

    return _connected;
  }


  Future<void> getUserRoles() async {

    roles.clear();

    print("Requesting user role data");

    // Next we request the permissions assigned to the current user
    // Note: 2021-02-27 this "roles" feature for the API was just introduced.
    // Any 'older' version of the server allows any API method for any logged in user!
    // We will return immediately, but request the user roles in the background

    var response = await get(_URL_GET_ROLES);

    // Null response from server
    if (response == null) {
      print("null response requesting user roles");
      return;
    }

    if (response.containsKey('roles')) {
      // Save a local copy of the user roles
      roles = response['roles'];
    }
  }

  bool checkPermission(String role, String permission) {
    /*
     * Check if the user has the given role.permission assigned
     *
     * e.g. 'part', 'change'
     */

    // If we do not have enough information, assume permission is allowed
    if (roles == null || roles.isEmpty) {
      return true;
    }

    if (!roles.containsKey(role)) {
      return true;
    }

    List<String> perms = List.from(roles[role]);

    return perms.contains(permission);
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

  HttpClient _client(bool allowBadCert) {

    var client = new HttpClient();

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) {
      // TODO - Introspection of actual certificate?

      if (allowBadCert) {
        return true;
      } else {
        showServerError(
          I18N.of(OneContext().context).serverCertificateError,
          "Server HTTPS certificate invalid"
        );
        return false;
      }

      return allowBadCert;
    });

    // Set the connection timeout
    client.connectionTimeout = Duration(seconds: 30);

    return client;
  }

  /**
   * Perform a HTTP GET request
   * Returns a json object (or null if did not complete)
   */
  Future<dynamic> get(String url, {Map<String, String> params}) async {
    var _url = makeApiUrl(url);
    var _headers = defaultHeaders();

    print("GET: ${_url}");

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

    var client = _client(true);

    print("Created client");

    HttpClientRequest request = await client.getUrl(Uri.parse(_url));

    // Set headers
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (profile != null) {
      request.headers.set(
          HttpHeaders.authorizationHeader,
          _authorizationHeader(profile.username, profile.password)
      );
    }

    print("Created request: ${request.uri}");

    HttpClientResponse response = await request.close()
    .timeout(Duration(seconds: 30))
    .catchError((error) {
      print("GET request returned error");
      print("URL: ${_url}");
      print("Error: ${error.toString()}");

      var ctx = OneContext().context;

      if (error is SocketException) {
        showServerError(
            I18N.of(ctx).connectionRefused,
            error.toString()
        );
      } else if (error is TimeoutException) {
        showTimeoutError(ctx);
      } else {
        showServerError(
            I18N.of(ctx).serverError,
            error.toString()
        );
      }

      return null;
    });

    // A null response means something has gone wrong...
    if (response == null) {
      print("null response from GET ${_url}");
      return null;
    }

    // Check the status code of the response
    if (response.statusCode != 200) {
      showStatusCodeError(response.statusCode);
      return null;
    }

    // Convert the body of the response to a JSON object
    String body = await response.transform(utf8.decoder).join();

    try {
      var data = json.decode(body);

      return data;

    } on FormatException {

      print("JSON format exception!");
      print("${body}");

      showServerError(
        "Format Exception",
        "JSON data format exception:\n${body}"
      );
      return null;
    }
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
      print("Using TOKEN: ${_token}");
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