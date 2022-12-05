import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:intl/intl.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/preferences.dart";

import "package:open_file/open_file.dart";
import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:flutter_cache_manager/flutter_cache_manager.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/widget/snacks.dart";
import "package:path_provider/path_provider.dart";

import "package:inventree/api_form.dart";


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

  bool successful() => (statusCode >= 200) && (statusCode < 300);

  bool redirected() => (statusCode >= 300) && (statusCode < 400);

  bool clientError() => (statusCode >= 400) && (statusCode < 500);

  bool serverError() => statusCode >= 500;

  bool isMap() {
    return data != null && data is Map<String, dynamic>;
  }

  Map<String, dynamic> asMap() {
    if (isMap()) {
      return data as Map<String, dynamic>;
    } else {
      // Empty map
      return {};
    }
  }

  bool isList() {
    return data != null && data is List<dynamic>;
  }

  List<dynamic> asList() {
    if (isList()) {
      return data as List<dynamic>;
    } else {
      return [];
    }
  }
}


/*
 * Custom FileService for caching network images
 * Requires a custom badCertificateCallback,
 * so we can accept "dodgy" (e.g. self-signed) certificates
 */
class InvenTreeFileService extends FileService {

  InvenTreeFileService({HttpClient? client, bool strictHttps = false}) {
    _client = client ?? HttpClient();

    if (_client != null) {
      _client!.badCertificateCallback = (cert, host, port) {
        print("BAD CERTIFICATE CALLBACK FOR IMAGE REQUEST");
        return !strictHttps;
      };
    }
  }

  HttpClient? _client;

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


/*
 * API class which manages all communication with the InvenTree server
 */
class InvenTreeAPI {

  factory InvenTreeAPI() {
    return _api;
  }

  InvenTreeAPI._internal();

  // List of callback functions to trigger when the connection status changes
  List<Function()> _statusCallbacks = [];

  // Register a callback function to be notified when the connection status changes
  void registerCallback(Function() func) => _statusCallbacks.add(func);

  void _connectionStatusChanged() {
    for (Function() func in _statusCallbacks) {
      // Call the function
      func();
    }
  }

  // Minimum required API version for server
  static const _minApiVersion = 20;

  bool _strictHttps = false;

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

    // Strip leading slash
    if (url.startsWith("/")) {
      url = url.substring(1, url.length);
    }

    // Prevent double-slash
    url = url.replaceAll("//", "/");

    return baseUrl + url;
  }

  String get apiUrl => _makeUrl("/api/");

  String get imageUrl => _makeUrl("/image/");

  String makeApiUrl(String endpoint) {
    if (endpoint.startsWith("/api/") || endpoint.startsWith("api/")) {
      return _makeUrl(endpoint);
    } else {
      return _makeUrl("/api/${endpoint}");
    }
  }

  String makeUrl(String endpoint) => _makeUrl(endpoint);

  UserProfile? profile;

  // Available user roles (permissions) are loaded when connecting to the server
  Map<String, dynamic> roles = {};

  // Authentication token (initially empty, must be requested)
  String _token = "";

  String? get serverAddress {
    return profile?.server;
  }

  bool get hasToken => _token.isNotEmpty;

  /*
   * Check server connection and display messages if not connected.
   * Useful as a precursor check before performing operations.
   */
  bool checkConnection() {
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
  String instance = "";

  // Server version information
  String _version = "";

  // API version of the connected server
  int _apiVersion = 1;

  int get apiVersion => _apiVersion;

  // Notification support requires API v25 or newer
  bool get supportsNotifications => isConnected() && apiVersion >= 25;

  // Supports 'modern' barcode API (v80 or newer)
  bool get supportModernBarcodes => isConnected() && apiVersion >= 80;

  // Structural categories requires API v83 or newer
  bool get supportsStructuralCategories => isConnected() && apiVersion >= 83;

  // Part parameter support requires API v56 or newer
  bool get supportsPartParameters => isConnected() && apiVersion >= 56;

  // Are plugins enabled on the server?
  bool _pluginsEnabled = false;

  // True plugin support requires API v34 or newer
  // Returns True only if the server API version is new enough, and plugins are enabled
  bool pluginsEnabled() => apiVersion >= 34 && _pluginsEnabled;

  // Cached list of plugins (refreshed when we connect to the server)
  List<InvenTreePlugin> _plugins = [];

  // Return a list of plugins enabled on the server
  // Can optionally filter by a particular 'mixin' type
  List<InvenTreePlugin> getPlugins({String mixin = ""}) {
    List<InvenTreePlugin> plugins = [];

    for (var plugin in _plugins) {
      // Do we wish to filter by a particular mixin?
      if (mixin.isNotEmpty) {
        if (!plugin.supportsMixin(mixin)) {
          continue;
        }
      }

      plugins.add(plugin);
    }

    // Return list of matching plugins
    return plugins;
  }

  // Test if the provided plugin mixin is supported by any active plugins
  bool supportsMixin(String mixin) => getPlugins(mixin: mixin).isNotEmpty;

  // Getter for server version information
  String get version => _version;

  // Connection status flag - set once connection has been validated
  bool _connected = false;

  bool _connecting = false;

  bool isConnected() {
    return profile != null && _connected && baseUrl.isNotEmpty && hasToken;
  }

  bool isConnecting() {
    return !isConnected() && _connecting;
  }

  // Ensure we only ever create a single instance of the API class
  static final InvenTreeAPI _api = InvenTreeAPI._internal();

  // API endpoint for receiving purchase order line items was introduced in v12
  bool get supportsPoReceive => apiVersion >= 12;

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

    // Cache the "strictHttps" setting, so we can use it later without async requirement
    _strictHttps = await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false) as bool;

    if (address.isEmpty || username.isEmpty || password.isEmpty) {
      showSnackIcon(
        L10().incompleteDetails,
        icon: FontAwesomeIcons.exclamationCircle,
        success: false
      );
      return false;
    }

    if (!address.endsWith("/")) {
      address = address + "/";
    }

    _BASE_URL = address;

    // Clear the list of available plugins
    _plugins.clear();

    debug("Connecting to ${apiUrl} -> username=${username}");

    APIResponse response;

    response = await get("", expectedStatusCode: 200);

    if (!response.successful()) {
      showStatusCodeError(apiUrl, response.statusCode);
      return false;
    }

    var data = response.asMap();

    // We expect certain response from the server
    if (!data.containsKey("server") || !data.containsKey("version") || !data.containsKey("instance")) {

      showServerError(
        apiUrl,
        L10().missingData,
        L10().serverMissingData,
      );

      return false;
    }

    // Record server information
    _version = (data["version"] ?? "") as String;
    instance = (data["instance"] ?? "") as String;

    // Default API version is 1 if not provided
    _apiVersion = (data["apiVersion"] ?? 1) as int;
    _pluginsEnabled = (data["plugins_enabled"] ?? false) as bool;

    if (_apiVersion < _minApiVersion) {

      String message = L10().serverApiVersion + ": ${_apiVersion}";

      message += "\n";
      message += L10().serverApiRequired + ": ${_minApiVersion}";

      message += "\n\n";

      message += "Ensure your InvenTree server version is up to date!";

      showServerError(
        apiUrl,
        L10().serverOld,
        message,
      );

      return false;
    }

    /**
     * Request user token information from the server
     * This is the stage that we check username:password credentials!
     */
    // Clear the existing token value
    _token = "";

    response = await get(_URL_GET_TOKEN);

    // Invalid response
    if (!response.successful()) {

      switch (response.statusCode) {
        case 401:
        case 403:
          showServerError(
            apiUrl,
            L10().serverAuthenticationError,
            L10().invalidUsernamePassword,
          );
          break;
        default:
          showStatusCodeError(apiUrl, response.statusCode);
          break;
      }

      debug("Token request failed: STATUS ${response.statusCode}");

      return false;
    }

    data = response.asMap();

    if (!data.containsKey("token")) {
      showServerError(
          apiUrl,
          L10().tokenMissing,
          L10().tokenMissingFromResponse,
      );

      return false;
    }

    // Return the received token
    _token = (data["token"] ?? "") as String;

    debug("Received token from server");

    // Request user role information (async)
    getUserRoles();

    // Request plugin information (async)
    getPluginInformation();

    // Ok, probably pretty good...
    return true;

  }

  void disconnectFromServer() {
    debug("API : disconnectFromServer()");

    _connected = false;
    _connecting = false;
    _token = "";
    profile = null;

    // Clear received settings
    _globalSettings.clear();
    _userSettings.clear();

    _connectionStatusChanged();
  }

  /*
   * Public facing connection function
   */
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

    _connectionStatusChanged();

    _connected = await _connect();

    _connecting = false;

    if (_connected) {
      showSnackIcon(
        L10().serverConnected,
        icon: FontAwesomeIcons.server,
        success: true,
      );
    }

    _connectionStatusChanged();

    return _connected;
  }

  /*
   * Request the user roles (permissions) from the InvenTree server
   */
  Future<bool> getUserRoles() async {

    roles.clear();

    debug("API: Requesting user role data");

    // Next we request the permissions assigned to the current user
    // Note: 2021-02-27 this "roles" feature for the API was just introduced.
    // Any "older" version of the server allows any API method for any logged in user!
    // We will return immediately, but request the user roles in the background

    final response = await get(_URL_GET_ROLES, expectedStatusCode: 200);

    if (!response.successful()) {
      return false;
    }

    var data = response.asMap();

    if (data.containsKey("roles")) {
      // Save a local copy of the user roles
      roles = (response.data["roles"] ?? {}) as Map<String, dynamic>;

      return true;
    } else {
      return false;
    }
  }

  // Request plugin information from the server
  Future<void> getPluginInformation() async {

    // The server does not support plugins, or they are not enabled
    if (!pluginsEnabled()) {
      _plugins.clear();
      return;
    }

    debug("API: getPluginInformation()");

    // Request a list of plugins from the server
    final List<InvenTreeModel> results = await InvenTreePlugin().list();

    for (var result in results) {
      if (result is InvenTreePlugin) {
        if (result.active) {
          // Only add plugins that are active
          _plugins.add(result);
        }
      }
    }
  }

  bool checkPermission(String role, String permission) {
    /*
     * Check if the user has the given role.permission assigned
     *e
     * e.g. "part", "change"
     */

    // If we do not have enough information, assume permission is allowed
    if (roles.isEmpty) {
      return true;
    }

    if (!roles.containsKey(role)) {
      return true;
    }

    if (roles[role] == null) {
      return true;
    }

    try {
      List<String> perms = List.from(roles[role] as List<dynamic>);
      return perms.contains(permission);
    } catch (error, stackTrace) {
      if (error is TypeError) {
        // Ignore TypeError
      } else {
        // Unknown error - report it!
        sentryReportError(
          "api.checkPermission",
          error, stackTrace,
          context: {
            "role": role,
            "permission": permission,
            "error": error.toString(),
         }
        );
      }

      // Unable to determine permission - assume true?
      return true;
    }
  }


  // Perform a PATCH request
  Future<APIResponse> patch(String url, {Map<String, dynamic> body = const {}, int? expectedStatusCode}) async {

    Map<String, dynamic> _body = body;

    HttpClientRequest? request = await apiRequest(url, "PATCH");

    if (request == null) {
      // Return an "invalid" APIResponse
      return APIResponse(
        url: url,
        method: "PATCH",
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
   * Download a file from the given URL
   */
  Future<void> downloadFile(String url, {bool openOnDownload = true}) async {

    // Find the local downlods directory
    final Directory dir = await getTemporaryDirectory();

    String filename = url.split("/").last;

    String local_path = dir.path + "/" + filename;

    Uri? _uri = Uri.tryParse(makeUrl(url));

    if (_uri == null) {
      showServerError(url, L10().invalidHost, L10().invalidHostDetails);
      return;
    }

    if (_uri.host.isEmpty) {
      showServerError(url, L10().invalidHost, L10().invalidHostDetails);
      return;
    }

    HttpClientRequest? _request;

    final bool strictHttps = await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false) as bool;

    var client = createClient(url, strictHttps: strictHttps);

    // Attempt to open a connection to the server
    try {
      _request = await client.openUrl("GET", _uri).timeout(Duration(seconds: 10));

      // Set headers
      _request.headers.set(HttpHeaders.authorizationHeader, _authorizationHeader());
      _request.headers.set(HttpHeaders.acceptHeader, "application/json");
      _request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      _request.headers.set(HttpHeaders.acceptLanguageHeader, Intl.getCurrentLocale());

    } on SocketException catch (error) {
      debug("SocketException at ${url}: ${error.toString()}");
      showServerError(url, L10().connectionRefused, error.toString());
      return;
    } on TimeoutException {
      debug("TimeoutException at ${url}");
      showTimeoutError(url);
      return;
    } on HandshakeException catch (error) {
      debug("HandshakeException at ${url}:");
      debug(error.toString());
      showServerError(url, L10().serverCertificateError, error.toString());
      return;
    } catch (error, stackTrace) {
      debug("Server error at ${url}: ${error.toString()}");
      showServerError(url, L10().serverError, error.toString());
      sentryReportError(
        "api.downloadFile : client.openUrl",
        error, stackTrace,
      );
      return;
    }

    try {
      final response = await _request.close();

      if (response.statusCode == 200) {
        var bytes = await consolidateHttpClientResponseBytes(response);

        File localFile = File(local_path);

        await localFile.writeAsBytes(bytes);

        if (openOnDownload) {
          OpenFile.open(local_path);
        }
      } else {
        showStatusCodeError(url, response.statusCode);
      }
    } on SocketException catch (error) {
      showServerError(url, L10().connectionRefused, error.toString());
    } on TimeoutException {
      showTimeoutError(url);
    } catch (error, stackTrace) {
      debug("Error downloading image:");
      debug(error.toString());
      showServerError(url, L10().downloadError, error.toString());
      sentryReportError(
        "api.downloadFile : client.closeRequest",
        error, stackTrace,
      );
    }
  }

  /*
   * Upload a file to the given URL
   */
  Future<APIResponse> uploadFile(String url, File f,
      {String name = "attachment", String method="POST", Map<String, dynamic>? fields}) async {
    var _url = makeApiUrl(url);

    var request = http.MultipartRequest(method, Uri.parse(_url));

    request.headers.addAll(defaultHeaders());

    if (fields != null) {
      fields.forEach((String key, dynamic value) {

        if (value == null) {
          request.fields[key] = "";
        } else {
          request.fields[key] = value.toString();
        }
      });
    }

    var _file = await http.MultipartFile.fromPath(name, f.path);

    request.files.add(_file);

    APIResponse response = APIResponse(
      url: url,
      method: method,
    );

    String jsondata = "";

    try {
      var httpResponse = await request.send().timeout(Duration(seconds: 120));

      response.statusCode = httpResponse.statusCode;

      jsondata = await httpResponse.stream.bytesToString();

      response.data = json.decode(jsondata);

      // Report a server-side error
      if (response.statusCode >= 500) {
        sentryReportMessage(
            "Server error in uploadFile()",
            context: {
              "url": url,
              "method": request.method,
              "name": name,
              "statusCode": response.statusCode.toString(),
              "requestHeaders": request.headers.toString(),
              "responseHeaders": httpResponse.headers.toString(),
            }
        );
      }
    } on SocketException catch (error) {
      showServerError(url, L10().connectionRefused, error.toString());
      response.error = "SocketException";
      response.errorDetail = error.toString();
    } on FormatException {
      showServerError(
        url,
        L10().formatException,
        L10().formatExceptionJson + ":\n${jsondata}"
      );

      sentryReportMessage(
          "Error decoding JSON response from server",
          context: {
            "method": "uploadFile",
            "url": url,
            "statusCode": response.statusCode.toString(),
            "data": jsondata,
          }
      );

    } on TimeoutException {
      showTimeoutError(url);
      response.error = "TimeoutException";
    } catch (error, stackTrace) {
      showServerError(url, L10().serverError, error.toString());
      sentryReportError(
        "api.uploadFile",
        error, stackTrace
      );
      response.error = "UnknownError";
      response.errorDetail = error.toString();
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
      return APIResponse(
        url: url,
        method: "OPTIONS"
      );
    }

    return completeRequest(request);
  }

  /*
   * Perform a HTTP POST request
   * Returns a json object (or null if unsuccessful)
   */
  Future<APIResponse> post(String url, {Map<String, dynamic> body = const {}, int? expectedStatusCode=201}) async {

    HttpClientRequest? request = await apiRequest(url, "POST");

    if (request == null) {
      // Return an "invalid" APIResponse
      return APIResponse(
        url: url,
        method: "POST"
      );
    }

    return completeRequest(
      request,
      data: json.encode(body),
      statusCode: expectedStatusCode
    );
  }

  /*
   * Perform a request to link a custom barcode to a particular item
   */
  Future<bool> linkBarcode(Map<String, String> body) async {

  HttpClientRequest? request = await apiRequest("/barcode/link/", "POST");

  if (request == null) {
    return false;
  }

  final response = await completeRequest(
    request,
    data: json.encode(body),
    statusCode: 200
  );

  return response.isValid() && response.statusCode == 200;

  }

  /*
   * Perform a request to unlink a custom barcode from a particular item
   */
  Future<bool> unlinkBarcode(Map<String, dynamic> body) async {

    HttpClientRequest? request = await apiRequest("/barcode/unlink/", "POST");

    if (request == null) {
      return false;
    }

    final response = await completeRequest(
        request,
        data: json.encode(body),
        statusCode: 200,
    );

    return response.isValid() && response.statusCode == 200;
  }


  HttpClient createClient(String url, {bool strictHttps = false}) {

    var client = HttpClient();

    client.badCertificateCallback = (X509Certificate cert, String host, int port) {

      if (strictHttps) {
        showServerError(
          url,
          L10().serverCertificateError,
          L10().serverCertificateInvalid,
        );
        return false;
      }

      // Strict HTTPs not enforced, so we'll ignore the bad cert
      return true;
    };

    // Set the connection timeout
    client.connectionTimeout = Duration(seconds: 30);

    return client;
  }

  /*
   * Initiate a HTTP request to the server
   *
   * @param url is the API endpoint
   * @param method is the HTTP method e.g. "POST" / "PATCH" / "GET" etc;
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
    if (_url.endsWith("&")) {
      _url = _url.substring(0, _url.length - 1);
    }

    Uri? _uri = Uri.tryParse(_url);

    if (_uri == null) {
      showServerError(url, L10().invalidHost, L10().invalidHostDetails);
      return null;
    }

    if (_uri.host.isEmpty) {
      showServerError(url, L10().invalidHost, L10().invalidHostDetails);
      return null;
    }

    HttpClientRequest? _request;

    final bool strictHttps = await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false) as bool;

    var client = createClient(url, strictHttps: strictHttps);

    // Attempt to open a connection to the server
    try {
      _request = await client.openUrl(method, _uri).timeout(Duration(seconds: 10));

      // Set headers
      _request.headers.set(HttpHeaders.authorizationHeader, _authorizationHeader());
      _request.headers.set(HttpHeaders.acceptHeader, "application/json");
      _request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      _request.headers.set(HttpHeaders.acceptLanguageHeader, Intl.getCurrentLocale());

      return _request;
    } on SocketException catch (error) {
      debug("SocketException at ${url}: ${error.toString()}");
      showServerError(url, L10().connectionRefused, error.toString());
      return null;
    } on TimeoutException {
      debug("TimeoutException at ${url}");
      showTimeoutError(url);
      return null;
    } on CertificateException catch (error) {
      debug("CertificateException at ${url}:");
      debug(error.toString());
      showServerError(url, L10().serverCertificateError, error.toString());
      return null;
    } on HandshakeException catch (error) {
      debug("HandshakeException at ${url}:");
      debug(error.toString());
      showServerError(url, L10().serverCertificateError, error.toString());
      return null;
    } catch (error, stackTrace) {
      debug("Server error at ${url}: ${error.toString()}");
      showServerError(url, L10().serverError, error.toString());
      sentryReportError(
        "api.apiRequest : openUrl",
        error, stackTrace,
        context: {
          "url": url,
          "method": method,
        }
      );
      return null;
    }
  }


  /*
   * Complete an API request, and return an APIResponse object
   */
  Future<APIResponse> completeRequest(HttpClientRequest request, {String? data, int? statusCode, bool ignoreResponse = false}) async {

    if (data != null && data.isNotEmpty) {

      var encoded_data = utf8.encode(data);

      request.headers.set(HttpHeaders.contentLengthHeader, encoded_data.length.toString());
      request.add(encoded_data);
    }

    APIResponse response = APIResponse(
      method: request.method,
      url: request.uri.toString()
    );

    String url = request.uri.toString();

    try {
      HttpClientResponse? _response = await request.close().timeout(Duration(seconds: 10));

      response.statusCode = _response.statusCode;

      // If the server returns a server error code, alert the user
      if (_response.statusCode >= 500) {
        showStatusCodeError(url, _response.statusCode);

        // Some server errors are not ones for us to worry about!
        switch (_response.statusCode) {
          case 502:   // Bad gateway
          case 504:   // Gateway timeout
            break;
          default:    // Any other error code
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
            break;
        }
      } else {

        // First check that the returned status code is what we expected
        if (statusCode != null && statusCode != _response.statusCode) {
          showStatusCodeError(url, _response.statusCode);
        } else if (ignoreResponse) {
          response.data = {};
        } else {
          response.data = await responseToJson(url, _response) ?? {};
        }
      }
    } on HttpException catch (error) {
      showServerError(url, L10().serverError, error.toString());
      response.error = "HTTPException";
      response.errorDetail = error.toString();
    } on SocketException catch (error) {
      showServerError(url, L10().connectionRefused, error.toString());
      response.error = "SocketException";
      response.errorDetail = error.toString();
    } on CertificateException catch (error) {
      debug("CertificateException at ${request.uri.toString()}:");
      debug(error.toString());
      showServerError(url, L10().serverCertificateError, error.toString());
    } on TimeoutException {
      showTimeoutError(url);
      response.error = "TimeoutException";
    } catch (error, stackTrace) {
      showServerError(url, L10().serverError, error.toString());
      sentryReportError("api.completeRequest", error, stackTrace);
      response.error = "UnknownError";
      response.errorDetail = error.toString();
    }

    return response;

  }

  /*
   * Convert a HttpClientResponse response object to JSON
   */
  dynamic responseToJson(String url, HttpClientResponse response) async {

    String body = await response.transform(utf8.decoder).join();

    try {
      var data = json.decode(body);

      return data ?? {};
    } on FormatException {

      switch (response.statusCode) {
        case 400:
        case 401:
        case 403:
        case 404:
          // Ignore for unauthorized pages
          break;
        default:
          sentryReportMessage(
              "Error decoding JSON response from server",
              context: {
                "headers": response.headers.toString(),
                "statusCode": response.statusCode.toString(),
                "data": body.toString(),
                "endpoint": url,
              }
          );
          break;
      }

      showServerError(
        url,
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
  Future<APIResponse> get(String url, {Map<String, String> params = const {}, int? expectedStatusCode=200}) async {

    HttpClientRequest? request = await apiRequest(
      url,
      "GET",
      urlParams: params,
    );

    if (request == null) {
      // Return an "invalid" APIResponse
      return APIResponse(
        url: url,
        method: "GET",
        error: "HttpClientRequest is null",
      );
    }

    return completeRequest(request);
  }

  /*
   * Perform a HTTP DELETE request
   */
  Future<APIResponse> delete(String url) async {

    HttpClientRequest? request = await apiRequest(
      url,
      "DELETE",
    );

    if (request == null) {
      // Return an "invalid" APIResponse object
      return APIResponse(
        url: url,
        method: "DELETE",
        error: "HttpClientRequest is null",
      );
    }

    return completeRequest(
      request,
      ignoreResponse: true,
    );
  }

  // Return a list of request headers
  Map<String, String> defaultHeaders() {
    Map<String, String> headers = {};

    headers[HttpHeaders.authorizationHeader] = _authorizationHeader();
    headers[HttpHeaders.acceptHeader] = "application/json";
    headers[HttpHeaders.contentTypeHeader] = "application/json";
    headers[HttpHeaders.acceptLanguageHeader] = Intl.getCurrentLocale();

    return headers;
  }

  String _authorizationHeader() {
    if (_token.isNotEmpty) {
      return "Token $_token";
    } else if (profile != null) {
      return "Basic " + base64Encode(utf8.encode("${profile?.username}:${profile?.password}"));
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
        fileService: InvenTreeFileService(
          strictHttps: _strictHttps,
        ),
      )
    );

    return CachedNetworkImage(
      imageUrl: url,
      placeholder: (context, url) => CircularProgressIndicator(),
      errorWidget: (context, url, error) => FaIcon(FontAwesomeIcons.timesCircle, color: COLOR_DANGER),
      httpHeaders: defaultHeaders(),
      height: height,
      width: width,
      cacheManager: manager,
    );
  }

  // Return True if the API supports 'settings' (requires API v46)
  bool get supportsSettings => isConnected() && apiVersion >= 46;

  // Keep a record of which settings we have received from the server
  Map<String, InvenTreeGlobalSetting> _globalSettings = {};
  Map<String, InvenTreeUserSetting> _userSettings = {};

  Future<String> getGlobalSetting(String key) async {
    if (!supportsSettings) return "";

    InvenTreeGlobalSetting? setting = _globalSettings[key];

    if ((setting != null) && setting.reloadedWithin(Duration(minutes: 5))) {
      return setting.value;
    }

    final response = await InvenTreeGlobalSetting().getModel(key);

    if (response is InvenTreeGlobalSetting) {
      response.lastReload = DateTime.now();
      _globalSettings[key] = response;
      return response.value;
    } else {
      return "";
    }
  }

  Future<String> getUserSetting(String key) async {
    if (!supportsSettings) return "";

    InvenTreeUserSetting? setting = _userSettings[key];

    if ((setting != null) && setting.reloadedWithin(Duration(minutes: 5))) {
      return setting.value;
    }

    final response = await InvenTreeGlobalSetting().getModel(key);

    if (response is InvenTreeUserSetting) {
      response.lastReload = DateTime.now();
      _userSettings[key] = response;
      return response.value;
    } else {
      return "";
    }
  }

  /*
   * Send a request to the server to locate / identify either a StockItem or StockLocation
   */
  Future<void> locateItemOrLocation(BuildContext context, {int? item, int? location}) async {

    var plugins = getPlugins(mixin: "locate");

    if (plugins.isEmpty) {
      // TODO: Error message
      return;
    }

    String plugin_name = "";

    if (plugins.length == 1) {
      plugin_name = plugins.first.key;
    } else {
      // User selects which plugin to use
      List<Map<String, dynamic>> plugin_options = [];

      for (var plugin in plugins) {
        plugin_options.add({
          "display_name": plugin.humanName,
          "value": plugin.key,
        });
      }

      Map<String, dynamic> fields = {
        "plugin": {
          "label": L10().plugin,
          "type": "choice",
          "value": plugins.first.key,
          "choices": plugin_options,
          "required": true,
        }
      };

      await launchApiForm(
          context,
          L10().locateLocation,
          "",
          fields,
          icon: FontAwesomeIcons.searchLocation,
          onSuccess: (Map<String, dynamic> data) async {
            plugin_name = (data["plugin"] ?? "") as String;
          }
      );
    }

    Map<String, dynamic> body = {
      "plugin": plugin_name,
    };

    if (item != null) {
      body["item"] = item.toString();
    }

    if (location != null) {
      body["location"] = location.toString();
    }

    post(
      "/api/locate/",
      body: body,
      expectedStatusCode: 200,
    ).then((APIResponse response) {
      if (response.successful()) {
        showSnackIcon(
          L10().requestSuccessful,
          success: true,
        );
      }
    });
  }
}
