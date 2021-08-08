import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:inventree/widget/dialogs.dart';
import 'package:inventree/l10.dart';
import 'package:inventree/inventree/sentry.dart';
import 'package:inventree/user_profile.dart';
import 'package:inventree/widget/snacks.dart';


/*
 * Class representing an API response from the server
 */
class APIResponse {

  APIResponse({this.url = "", this.method = "", this.statusCode = -1, this.error = "", this.data = const {}});

  int statusCode = -1;

  String url = "";

  String method = "";

  String error = "";

  String errorDetail = "";

  dynamic data = {};

  // Request is "valid" if a statusCode was returned
  bool isValid() => (statusCode >= 0) && (statusCode < 500);
}


/*
 * Custom FileService for caching network images
 * Requires a custom badCertificateCallback,
 * so we can accept "dodgy" certificates
 */
class InvenTreeFileService extends FileService {

  HttpClient? _client;

  InvenTreeFileService({HttpClient? client, bool strictHttps = false}) {
    _client = client ?? HttpClient();

    if (_client != null) {
      _client?.badCertificateCallback = (cert, host, port) {
        print("BAD CERTIFICATE CALLBACK FOR IMAGE REQUEST");
        return !strictHttps;
      };
    }
  }

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    final Uri resolved = Uri.base.resolve(url);

    final HttpClientRequest req = await _client!.getUrl(resolved);

    if (headers != null) {
      headers.forEach((key, value) {
        req.headers.add(key, value);
      });
    }

    final HttpClientResponse httpResponse = await req.close();
    final http.StreamedResponse _response = http.StreamedResponse(
      httpResponse.timeout(Duration(seconds: 60)), httpResponse.statusCode,
      contentLength: httpResponse.contentLength,
      reasonPhrase: httpResponse.reasonPhrase,
      isRedirect: httpResponse.isRedirect,
    );
    return HttpGetResponse(_response);
  }
}

/*
 * InvenTree API - Access to the InvenTree REST interface.
 *
 * InvenTree implements token-based authentication, which is
 * initialised using a username:password combination.
 */


class InvenTreeAPI {

  // Minimum required API version for server
  static const _minApiVersion = 7;

  // Endpoint for requesting an API token
  static const _URL_GET_TOKEN = "user/token/";

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

  String makeApiUrl(String endpoint) {
    if (endpoint.startsWith("/api/") || endpoint.startsWith("api/")) {
      return _makeUrl(endpoint);
    } else {
      return _makeUrl("/api/" + endpoint);
    }
  }

  String makeUrl(String endpoint) => _makeUrl(endpoint);

  UserProfile? profile;

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
        L10().notConnected,
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


  /*
   * Connect to the remote InvenTree server:
   *
   * - Check that the InvenTree server exists
   * - Request user token from the server
   * - Request user roles from the server
   */
  Future<bool> _connect() async {

    if (profile == null) return false;

    String address = profile?.server ?? "";
    String username = profile?.username ?? "";
    String password = profile?.password ?? "";

    address = address.trim();
    username = username.trim();
    password = password.trim();

    if (address.isEmpty || username.isEmpty || password.isEmpty) {
      showSnackIcon(
        "Incomplete profile details",
        icon: FontAwesomeIcons.exclamationCircle,
        success: false
      );
      return false;
    }

    if (!address.endsWith('/')) {
      address = address + '/';
    }
    /* TODO: Better URL validation
     * - If not a valid URL, return error
     * - If no port supplied, append a default port
     */

    _BASE_URL = address;

    print("Connecting to ${apiUrl} -> username=${username}");

    APIResponse response;

    response = await get("", expectedStatusCode: 200);

    // Response was invalid for some reason
    if (!response.isValid()) {
      return false;
    }

    if (response.statusCode != 200) {
      showStatusCodeError(response.statusCode);
      return false;
    }

    // We expect certain response from the server
    if (response.data == null || !response.data.containsKey("server") || !response.data.containsKey("version") || !response.data.containsKey("instance")) {

      showServerError(
        L10().missingData,
        L10().serverMissingData,
      );

      return false;
    }

    // Record server information
    _version = response.data["version"];
    instance = response.data['instance'] ?? '';

    // Default API version is 1 if not provided
    _apiVersion = (response.data['apiVersion'] ?? 1) as int;

    if (_apiVersion < _minApiVersion) {

      String message = L10().serverApiVersion + ": ${_apiVersion}";

      message += "\n";
      message += L10().serverApiRequired + ": ${_minApiVersion}";

      message += "\n\n";

      message += "Ensure your InvenTree server version is up to date!";

      showServerError(
        L10().serverOld,
        message
      );

      return false;
    }

    /**
     * Request user token information from the server
     * This is the stage that we check username:password credentials!
     */
    // Clear the existing token value
    _token = "";

    print("Requesting token from server");

    response = await get(_URL_GET_TOKEN);

    // Invalid response
    if (!response.isValid()) {
      return false;
    }

    if (response.statusCode != 200) {

      switch (response.statusCode) {
        case 401:
        case 403:
          showServerError(
            L10().serverAuthenticationError,
            L10().invalidUsernamePassword,
          );
          break;
        default:
          showStatusCodeError(response.statusCode);
          break;
      }

      return false;
    }

    if (response.data == null || !response.data.containsKey("token")) {
      showServerError(
          L10().tokenMissing,
          L10().tokenMissingFromResponse,
      );

      return false;
    }

    // Return the received token
    _token = response.data["token"];
    print("Received token - $_token");

    // Request user role information
    await getUserRoles();

    // Ok, probably pretty good...
    return true;

  }

  void disconnectFromServer() {
    print("InvenTreeAPI().disconnectFromServer()");

    _connected = false;
    _connecting = false;
    _token = '';
    profile = null;
  }

  Future<bool> connectToServer() async {

    // Ensure server is first disconnected
    disconnectFromServer();

    // Load selected profile
    profile = await UserProfileDBManager().getSelectedProfile();

    if (profile == null) {
      showSnackIcon(
          L10().profileSelect,
          success: false,
          icon: FontAwesomeIcons.exclamationCircle
      );
      return false;
    }

    _connecting = true;

    _connected = await _connect();

    _connecting = false;

    if (_connected) {
      showSnackIcon(
        L10().serverConnected,
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

    var response = await get(_URL_GET_ROLES, expectedStatusCode: 200);

    if (!response.isValid() || response.statusCode != 200) {
      return;
    }

    if (response.data.containsKey('roles')) {
      // Save a local copy of the user roles
      roles = response.data['roles'];
    }
  }

  bool checkPermission(String role, String permission) {
    /*
     * Check if the user has the given role.permission assigned
     *e
     * e.g. 'part', 'change'
     */

    // If we do not have enough information, assume permission is allowed
    if (roles.isEmpty) {
      return true;
    }

    if (!roles.containsKey(role)) {
      return true;
    }

    try {
      List<String> perms = List.from(roles[role]);
      return perms.contains(permission);
    } catch (error, stackTrace) {
      sentryReportError(error, stackTrace);
      return true;
    }
  }


  // Perform a PATCH request
  Future<APIResponse> patch(String url, {Map<String, String> body = const {}, int? expectedStatusCode}) async {
    var _body = Map<String, String>();

    // Copy across provided data
    body.forEach((K, V) => _body[K] = V);

    HttpClientRequest? request = await apiRequest(url, "PATCH");

    if (request == null) {
      // Return an "invalid" APIResponse
      return new APIResponse(
        url: url,
        method: 'PATCH',
        error: "HttpClientRequest is null"
      );
    }

    return completeRequest(
      request,
      data: json.encode(_body),
      statusCode: expectedStatusCode
    );
  }

  /*
   * Upload a file to the given URL
   */
  Future<http.StreamedResponse> uploadFile(String url, File f,
      {String name = "attachment", String method="POST", Map<String, String>? fields}) async {

    var _url = makeApiUrl(url);

    var request = http.MultipartRequest(method, Uri.parse(_url));

    request.headers.addAll(defaultHeaders());

    if (fields != null) {
      fields.forEach((String key, String value) {
        request.fields[key] = value;
      });
    }

    var _file = await http.MultipartFile.fromPath(name, f.path);

    request.files.add(_file);

    var response = await request.send();

    if (response.statusCode >= 500) {
      // Server error
      if (response.statusCode >= 500) {

        var data = await response.stream.bytesToString();

        sentryReportMessage(
            "Server error on file upload",
            context: {
              "url": _url,
              "statusCode": "${response.statusCode}",
              "response": response.toString(),
              "request": request.fields.toString(),
              "data": data,
            }
        );
      }
    }

    return response;
  }

  /*
   * Perform a HTTP OPTIONS request,
   * to get the available fields at a given endpoint.
   * We send this with the currently selected "locale",
   * so that (hopefully) the field messages are correctly translated
   */
  Future<APIResponse> options(String url) async {

    HttpClientRequest? request = await apiRequest(url, "OPTIONS");

    if (request == null) {
      // Return an "invalid" APIResponse
      return new APIResponse(
        url: url,
        method: 'OPTIONS'
      );
    }

    return completeRequest(request);
  }

  /*
   * Perform a HTTP POST request
   * Returns a json object (or null if unsuccessful)
   */
  Future<APIResponse> post(String url, {Map<String, dynamic> body = const {}, int expectedStatusCode=201}) async {

    HttpClientRequest? request = await apiRequest(url, "POST");

    if (request == null) {
      // Return an "invalid" APIResponse
      return new APIResponse(
        url: url,
        method: 'POST'
      );
    }

    return completeRequest(
      request,
      data: json.encode(body),
      statusCode: expectedStatusCode
    );
  }

  HttpClient createClient(bool allowBadCert) {

    var client = new HttpClient();

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) {
      // TODO - Introspection of actual certificate?

      allowBadCert = true;

      if (allowBadCert) {
        return true;
      } else {
        showServerError(
          L10().serverCertificateError,
          L10().serverCertificateInvalid,
        );
        return false;
      }
    });

    // Set the connection timeout
    client.connectionTimeout = Duration(seconds: 30);

    return client;
  }

  /*
   * Initiate a HTTP request to the server
   *
   * @param url is the API endpoint
   * @param method is the HTTP method e.g. 'POST' / 'PATCH' / 'GET' etc;
   * @param params is the request parameters
   */
  Future<HttpClientRequest?> apiRequest(String url, String method, {Map<String, String> urlParams = const {}}) async {

    var _url = makeApiUrl(url);

    // Add any required query parameters to the URL using ?key=value notation
    if (urlParams.isNotEmpty) {
      String query = "?";

      urlParams.forEach((k, v) => query += "${k}=${v}&");

      _url += query;
    }

    // Remove extraneous character if present
    if (_url.endsWith('&')) {
      _url = _url.substring(0, _url.length - 1);
    }

    Uri? _uri = Uri.tryParse(_url);

    if (_uri == null) {
      showServerError(L10().invalidHost, L10().invalidHostDetails);
      return null;
    }

    if (_uri.host.isEmpty) {
      showServerError(L10().invalidHost, L10().invalidHostDetails);
      return null;
    }

    HttpClientRequest? _request;

    var client = createClient(true);

    // Attempt to open a connection to the server
    try {
      _request = await client.openUrl(method, _uri).timeout(Duration(seconds: 10));

      // Set headers
      _request.headers.set(HttpHeaders.authorizationHeader, _authorizationHeader());
      _request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      _request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      _request.headers.set(HttpHeaders.acceptLanguageHeader, Intl.getCurrentLocale());

      return _request;
    } on SocketException catch (error) {
      print("SocketException at ${url}: ${error.toString()}");
      showServerError(L10().connectionRefused, error.toString());
      return null;
    } on TimeoutException {
      print("TimeoutException at ${url}");
      showTimeoutError();
      return null;
    } catch (error, stackTrace) {
      print("Server error at ${url}: ${error.toString()}");
      showServerError(L10().serverError, error.toString());
      sentryReportError(error, stackTrace);
      return null;
    }
  }


  /*
   * Complete an API request, and return an APIResponse object
   */
  Future<APIResponse> completeRequest(HttpClientRequest request, {String? data, int? statusCode}) async {

    if (data != null && data.isNotEmpty) {
      request.headers.set(HttpHeaders.contentLengthHeader, data.length.toString());
      request.add(utf8.encode(data));
    }

    APIResponse response = new APIResponse(
      method: request.method,
      url: request.uri.toString()
    );

    try {
      HttpClientResponse? _response = await request.close().timeout(Duration(seconds: 10));

      response.statusCode = _response.statusCode;

      // If the server returns a server error code, alert the user
      if (_response.statusCode >= 500) {
        showStatusCodeError(_response.statusCode);
      } else {
        response.data = await responseToJson(_response) ?? {};

        if (statusCode != null) {

          // Expected status code not returned
          if (statusCode != _response.statusCode) {
            showStatusCodeError(_response.statusCode);
          }

          // Report any server errors
          if (_response.statusCode >= 500) {
            sentryReportMessage(
                "Server error",
                context: {
                  "url": request.uri.toString(),
                  "method": request.method,
                  "statusCode": _response.statusCode.toString(),
                  "requestHeaders": request.headers.toString(),
                  "responseHeaders": _response.headers.toString(),
                  "responseData": response.data.toString(),
                }
            );
          }
        }
      }

    } on SocketException catch (error) {
      showServerError(L10().connectionRefused, error.toString());
      response.error = "SocketException";
      response.errorDetail = error.toString();

    } on TimeoutException {
      showTimeoutError();
      response.error = "TimeoutException";
    } catch (error, stackTrace) {
      showServerError(L10().serverError, error.toString());
      sentryReportError(error, stackTrace);
      response.error = "UnknownError";
      response.errorDetail = error.toString();
    }

    return response;

  }

  /*
   * Convert a HttpClientResponse response object to JSON
   */
  dynamic responseToJson(HttpClientResponse response) async {

    String body = await response.transform(utf8.decoder).join();

    try {
      var data = json.decode(body);

      return data ?? {};
    } on FormatException {

      print("JSON format exception!");
      print("${body}");

      sentryReportMessage(
        "Error decoding JSON response from server",
        context: {
          "headers": response.headers.toString(),
          "statusCode": response.statusCode.toString(),
          "data": body.toString(),
        }
      );

      showServerError(
        L10().formatException,
        L10().formatExceptionJson + ":\n${body}"
      );

      // Return an empty map
      return {};
    }

  }

  /*
   * Perform a HTTP GET request
   * Returns a json object (or null if did not complete)
   */
  Future<APIResponse> get(String url, {Map<String, String> params = const {}, int expectedStatusCode=200}) async {

    HttpClientRequest? request = await apiRequest(
      url,
      "GET",
      urlParams: params,
    );

    if (request == null) {
      // Return an "invalid" APIResponse
      return new APIResponse(
        url: url,
        method: 'GET',
        error: "HttpClientRequest is null",
      );
    }

    return completeRequest(request);
  }

  // Return a list of request headers
  Map<String, String> defaultHeaders() {
    var headers = Map<String, String>();

    headers[HttpHeaders.authorizationHeader] = _authorizationHeader();
    headers[HttpHeaders.acceptHeader] = 'application/json';
    headers[HttpHeaders.contentTypeHeader] = 'application/json';
    headers[HttpHeaders.acceptLanguageHeader] = Intl.getCurrentLocale();

    return headers;
  }

  String _authorizationHeader() {
    if (_token.isNotEmpty) {
      return "Token $_token";
    } else if (profile != null) {
      return "Basic " + base64Encode(utf8.encode('${profile?.username}:${profile?.password}'));
    } else {
      return "";
    }
  }

  static String get staticImage => "/static/img/blank_image.png";

  static String get staticThumb => "/static/img/blank_image.thumbnail.png";

  /*
   * Load image from the InvenTree server,
   * or from local cache (if it has been cached!)
   */
  CachedNetworkImage getImage(String imageUrl, {double? height, double? width}) {
    if (imageUrl.isEmpty) {
      imageUrl = staticImage;
    }

    String url = makeUrl(imageUrl);

    const key = "inventree_network_image";

    CacheManager manager = CacheManager(
      Config(
        key,
        fileService: InvenTreeFileService(),
      )
    );

    return new CachedNetworkImage(
      imageUrl: url,
      placeholder: (context, url) => CircularProgressIndicator(),
      errorWidget: (context, url, error) => Icon(FontAwesomeIcons.exclamation),
      httpHeaders: defaultHeaders(),
      height: height,
      width: width,
      cacheManager: manager,
    );
  }
}
