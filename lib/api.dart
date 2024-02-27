import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:intl/intl.dart";
import "package:inventree/main.dart";
import "package:one_context/one_context.dart";
import "package:open_filex/open_filex.dart";
import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:flutter_cache_manager/flutter_cache_manager.dart";
import "package:path_provider/path_provider.dart";

import "package:inventree/api_form.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/preferences.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/notification.dart";
import "package:inventree/inventree/status_codes.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/snacks.dart";


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

  /*
   * Helper function to interpret response, and return a list.
   * Handles case where the response is paginated, or a complete set of results
   */
  List<dynamic> resultsList() {

    if (isList()) {
      return asList();
    } else if (isMap()) {
      var response = asMap();
      if (response.containsKey("results")) {
        return response["results"] as List<dynamic>;
      } else {
        return [];
      }
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
      contentLength: httpResponse.contentLength < 0 ? 0 : httpResponse.contentLength,
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

  // Ensure we only ever create a single instance of the API class
  static final InvenTreeAPI _api = InvenTreeAPI._internal();

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
  static const _URL_TOKEN = "user/token/";
  static const _URL_ROLES = "user/roles/";
  static const _URL_ME = "user/me/";

  // Accessors for various url endpoints
  String get baseUrl {
    String url = profile?.server ?? "";

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

  // Profile authentication token
  String get token => profile?.token ?? "";

  bool get hasToken => token.isNotEmpty;

  String? get serverAddress {
    return profile?.server;
  }

  /*
   * Check server connection and display messages if not connected.
   * Useful as a precursor check before performing operations.
   */
  bool checkConnection() {

    // Is the server connected?
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

  // Map of user information
  Map<String, dynamic> userInfo = {};

  String get username => (userInfo["username"] ?? "") as String;

  // Map of server information
  Map<String, dynamic> serverInfo = {};

  String get serverInstance => (serverInfo["instance"] ?? "") as String;
  String get serverVersion => (serverInfo["version"] ?? "") as String;
  int get apiVersion => (serverInfo["apiVersion"] ?? 1) as int;

  // Plugins enabled at API v34 and above
  bool get pluginsEnabled => apiVersion >= 34 && (serverInfo["plugins_enabled"] ?? false) as bool;

  // API endpoint for receiving purchase order line items was introduced in v12
  bool get supportsPoReceive => apiVersion >= 12;

  // Notification support requires API v25 or newer
  bool get supportsNotifications => isConnected() && apiVersion >= 25;

  // Return True if the API supports 'settings' (requires API v46)
  bool get supportsSettings => isConnected() && apiVersion >= 46;

  // Part parameter support requires API v56 or newer
  bool get supportsPartParameters => isConnected() && apiVersion >= 56;

  // Supports 'modern' barcode API (v80 or newer)
  bool get supportModernBarcodes => isConnected() && apiVersion >= 80;

  // Structural categories requires API v83 or newer
  bool get supportsStructuralCategories => isConnected() && apiVersion >= 83;

  // Company attachments require API v95 or newer
  bool get supportCompanyAttachments => isConnected() && apiVersion >= 95;

  // Consolidated search request API v102 or newer
  bool get supportsConsolidatedSearch => isConnected() && apiVersion >= 102;

  // ReturnOrder supports API v104 or newer
  bool get supportsReturnOrders => isConnected() && apiVersion >= 104;

  // "Contact" model exposed to API
  bool get supportsContactModel => isConnected() && apiVersion >= 104;

  // Status label endpoints API v105 or newer
  bool get supportsStatusLabelEndpoints => isConnected() && apiVersion >= 105;

  // Regex search API v106 or newer
  bool get supportsRegexSearch => isConnected() && apiVersion >= 106;

  // Order barcodes API v107 or newer
  bool get supportsOrderBarcodes => isConnected() && apiVersion >= 107;

  // Project codes require v109 or newer
  bool get supportsProjectCodes => isConnected() && apiVersion >= 109;

  // Does the server support extra fields on stock adjustment actions?
  bool get supportsStockAdjustExtraFields => isConnected() && apiVersion >= 133;

  // Does the server support receiving items against a PO using barcodes?
  bool get supportsBarcodePOReceiveEndpoint => isConnected() && apiVersion >= 139;

  // Does the server support adding line items to a PO using barcodes?
  bool get supportsBarcodePOAddLineEndpoint => isConnected() && apiVersion >= 153;

  // Does the server support allocating stock to sales order using barcodes?
  bool get supportsBarcodeSOAllocateEndpoint => isConnected() && apiVersion >= 160;

  // Does the server support "null" top-level filtering for PartCategory and StockLocation endpoints?
  bool get supportsNullTopLevelFiltering => isConnected() && apiVersion < 174;

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

  // Connection status flag - set once connection has been validated
  bool _connected = false;

  bool _connecting = false;

  bool isConnected() {
    return profile != null && _connected && baseUrl.isNotEmpty && hasToken;
  }

  bool isConnecting() {
    return !isConnected() && _connecting;
  }


  /*
   * Perform the required login steps, in sequence.
   * Internal function, called by connectToServer()
   *
   * Performs the following steps:
   *
   * 1. Check the api/ endpoint to see if the sever exists
   * 2. If no token available, perform user authentication
   * 2. Check the api/user/me/ endpoint to see if the user is authenticated
   * 3. If not authenticated, purge token, and exit
   * 4. Request user roles
   * 5. Request information on available plugins
   */
  Future<bool> _connectToServer() async {

    if (!await _checkServer()) {
      return false;
    }

    if (!hasToken) {
      return false;
    }

    if (!await _checkAuth()) {
      showServerError(_URL_ME, L10().serverNotConnected, L10().serverAuthenticationError);

      // Invalidate the token
      if (profile != null) {
        profile!.token = "";
        await UserProfileDBManager().updateProfile(profile!);
      }

      return false;
    }

    if (!await _fetchRoles()) {
      return false;
    }

    if (!await _fetchPlugins()) {
      return false;
    }

    // Finally, connected
    return true;
  }


  /*
   * Check that the remote server is available.
   * Ping the api/ endpoint, which does not require user authentication
   */
  Future<bool> _checkServer() async {

    String address = profile?.server ?? "";

    if (address.isEmpty) {
      showSnackIcon(
          L10().incompleteDetails,
          icon: FontAwesomeIcons.circleExclamation,
          success: false
      );
      return false;
    }

    if (!address.endsWith("/")) {
      address = address + "/";
    }

    // Cache the "strictHttps" setting, so we can use it later without async requirement
    _strictHttps = await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false) as bool;

    debug("Connecting to ${apiUrl}");

    APIResponse response = await get("", expectedStatusCode: 200);

    if (!response.successful()) {
      debug("Server returned invalid response: ${response.statusCode}");
      showStatusCodeError(apiUrl, response.statusCode, details: response.data.toString());
      return false;
    }

    Map<String, dynamic> _data = response.asMap();

    serverInfo = {..._data};

    if (serverVersion.isEmpty) {
      showServerError(
        apiUrl,
        L10().missingData,
        L10().serverMissingData,
      );

      return false;
    }

    if (apiVersion < _minApiVersion) {

      String message = L10().serverApiVersion + ": ${apiVersion}";

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

    // At this point, we have a server which is responding
    return true;
  }


  /*
   * Check that the user is authenticated
   * Fetch the user information
   */
  Future<bool> _checkAuth() async {
    debug("Checking user auth @ ${_URL_ME}");

    userInfo.clear();

    final response = await get(_URL_ME);

    if (response.successful() && response.statusCode == 200) {
      userInfo = response.asMap();
      return true;
    } else {
      debug("Auth request failed: Server returned status ${response.statusCode}");
      if (response.data != null) {
        debug("Server response: ${response.data.toString()}");
      }

      return false;
    }
  }

  /*
   * Fetch a token from the server,
   * with a temporary authentication header
   */
  Future<APIResponse> fetchToken(UserProfile userProfile, String username, String password) async {

    debug("Fetching user token from ${userProfile.server}");

    profile = userProfile;

    // Form a name to request the token with
    String platform_name = "inventree-mobile-app";

    final deviceInfo = await getDeviceInfo();

    if (Platform.isAndroid) {
      platform_name += "-android";
    } else if (Platform.isIOS) {
      platform_name += "-ios";
    } else if (Platform.isMacOS) {
      platform_name += "-macos";
    } else if (Platform.isLinux) {
      platform_name += "-linux";
    } else if (Platform.isWindows) {
      platform_name += "-windows";
    }

    if (deviceInfo.containsKey("name")) {
      platform_name += "-" + (deviceInfo["name"] as String);
    }

    if (deviceInfo.containsKey("model")) {
      platform_name += "-" + (deviceInfo["model"] as String);
    }

    if (deviceInfo.containsKey("systemVersion")) {
      platform_name += "-" + (deviceInfo["systemVersion"] as String);
    }

    // Construct auth header from username and password
    String authHeader = "Basic " + base64Encode(utf8.encode("${username}:${password}"));

    // Perform request to get a token
    final response = await get(
        _URL_TOKEN,
        params: { "name": platform_name},
        headers: { HttpHeaders.authorizationHeader: authHeader}
    );

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

      if (response.data != null) {
        debug("Response data: ${response.data.toString()}");
      }
    }

    final data = response.asMap();

    if (!data.containsKey("token")) {
      showServerError(
        apiUrl,
        L10().tokenMissing,
        L10().tokenMissingFromResponse,
      );
    }

    // Save the token to the user profile
    userProfile.token = (data["token"] ?? "") as String;

    debug("Received token from server: ${userProfile.token}");

    await UserProfileDBManager().updateProfile(userProfile);

    return response;
  }

  void disconnectFromServer() {
    debug("API : disconnectFromServer()");

    _connected = false;
    _connecting = false;
    profile = null;

    // Clear received settings
    _globalSettings.clear();
    _userSettings.clear();

    roles.clear();
    _plugins.clear();
    serverInfo.clear();
    _connectionStatusChanged();
  }


  /* Public facing connection function.
   */
  Future<bool> connectToServer(UserProfile prf) async {

    // Ensure server is first disconnected
    disconnectFromServer();

    profile = prf;

    if (profile == null) {
      showSnackIcon(
          L10().profileSelect,
          success: false,
          icon: FontAwesomeIcons.circleExclamation
      );
      return false;
    }

    // Cancel notification timer
    _notification_timer?.cancel();

    _connecting = true;
    _connectionStatusChanged();

    // Perform the actual connection routine
    _connected = await _connectToServer();
    _connecting = false;

    if (_connected) {
      showSnackIcon(
        L10().serverConnected,
        icon: FontAwesomeIcons.server,
        success: true,
      );

      if (_notification_timer == null) {
        debug("starting notification timer");
        _notification_timer = Timer.periodic(
            Duration(seconds: 5),
                (timer) {
              _refreshNotifications();
            });
      }
    }

    _connectionStatusChanged();

    fetchStatusCodeData();

    return _connected;
  }

  /*
   * Request the user roles (permissions) from the InvenTree server
   */
  Future<bool> _fetchRoles() async {

    roles.clear();

    debug("API: Requesting user role data");

    final response = await get(_URL_ROLES, expectedStatusCode: 200);

    if (!response.successful()) {
      return false;
    }

    var data = response.asMap();

    if (data.containsKey("roles")) {
      // Save a local copy of the user roles
      roles = (response.data["roles"] ?? {}) as Map<String, dynamic>;

      return true;
    } else {
      showServerError(
        apiUrl,
        L10().serverError,
        L10().errorUserRoles,
      );
      return false;
    }
  }

  // Request plugin information from the server
  Future<bool> _fetchPlugins() async {

    _plugins.clear();

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

    return true;
  }

  /*
   * Check if the user has the given role.permission assigned
   * e.g. "part", "change"
   */
  bool checkPermission(String role, String permission) {

    if (!_connected) {
      return false;
    }

    // If we do not have enough information, assume permission is allowed
    if (roles.isEmpty) {
      debug("checkPermission - no roles defined!");
      return true;
    }

    if (!roles.containsKey(role)) {
      debug("checkPermission - role '$role' not found!");
      return true;
    }

    if (roles[role] == null) {
      debug("checkPermission - role '$role' is null!");
      return false;
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
      defaultHeaders().forEach((key, value) {
        _request?.headers.set(key, value);
      });

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
          OpenFilex.open(local_path);
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
      if (response.statusCode == 500) {
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
  Future<HttpClientRequest?> apiRequest(
      String url,
      String method,
      {
        Map<String, String> urlParams = const {},
        Map<String, String> headers = const {},
      }
    ) async {

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

      // Default headers
      defaultHeaders().forEach((key, value) {
        _request?.headers.set(key, value);
      });

      // Custom headers
      headers.forEach((key, value) {
        _request?.headers.set(key, value);
      });

      return _request;
    } on SocketException catch (error) {
      debug("SocketException at ${url}: ${error.toString()}");
      showServerError(url, L10().connectionRefused, error.toString());
      return null;
    } on TimeoutException {
      debug("TimeoutException at ${url}");
      showTimeoutError(url);
      return null;
    } on OSError catch (error) {
      debug("OSError at ${url}: ${error.toString()}");
      showServerError(url, L10().connectionRefused, error.toString());
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
          case 503:   // Service unavailable
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

        response.data = ignoreResponse ? {} : await responseToJson(url, _response) ?? {};

        // First check that the returned status code is what we expected
        if (statusCode != null && statusCode != _response.statusCode) {
          showStatusCodeError(url, _response.statusCode, details: response.data.toString());
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
        case 502:
        case 503:
        case 504:
          // Ignore for server errors
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
  Future<APIResponse> get(String url, {Map<String, String> params = const {}, Map<String, String> headers = const {}, int? expectedStatusCode=200}) async {

    HttpClientRequest? request = await apiRequest(
      url,
      "GET",
      urlParams: params,
      headers: headers,
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

  // Find the current locale code for the running app
  String get currentLocale {

    if (OneContext.hasContext) {
      // Try to get app context
      BuildContext? context = OneContext().context;

      if (context != null) {
        Locale? locale = InvenTreeApp
            .of(context)
            ?.locale;

        if (locale != null) {
          return locale.languageCode; //.toString();
        }
      }
    }

    // Fallback value
    return Intl.getCurrentLocale();
  }

  // Return a list of request headers
  Map<String, String> defaultHeaders() {
    Map<String, String> headers = {};

    if (hasToken) {
      headers[HttpHeaders.authorizationHeader] = _authorizationHeader();
    }

    headers[HttpHeaders.acceptHeader] = "application/json";
    headers[HttpHeaders.contentTypeHeader] = "application/json";
    headers[HttpHeaders.acceptLanguageHeader] = currentLocale;

    return headers;
  }

  // Construct a token authorization header
  String _authorizationHeader() {
    if (token.isNotEmpty) {
      return "Token ${token}";
    } else {
      return "";
    }
  }

  static String get staticImage => "/static/img/blank_image.png";

  static String get staticThumb => "/static/img/blank_image.thumbnail.png";

  CachedNetworkImage? getThumbnail(String imageUrl, {double size = 40, bool hideIfNull = false}) {

    if (hideIfNull) {
      if (imageUrl.isEmpty) {
        return null;
      }
    }

    try {
      return getImage(
          imageUrl,
          width: size,
          height: size
      );
    } catch (error, stackTrace) {
      sentryReportError("_getThumbnail", error, stackTrace);
      return null;
    }
  }

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
      errorWidget: (context, url, error) => FaIcon(FontAwesomeIcons.circleXmark, color: COLOR_DANGER),
      httpHeaders: defaultHeaders(),
      height: height,
      width: width,
      cacheManager: manager,
    );
  }

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

  // Return a boolean global setting value
  Future<bool> getGlobalBooleanSetting(String key) async {
    String value = await getGlobalSetting(key);
    return value.toLowerCase() == "true";
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

  // Return a boolean user setting value
  Future<bool> getUserBooleanSetting(String key) async {
    String value = await getUserSetting(key);
    return value.toLowerCase() == "true";
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
          icon: FontAwesomeIcons.magnifyingGlassLocation,
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

  // Keep an internal map of status codes
  Map<String, InvenTreeStatusCode> _status_codes = {};

  // Return a status class based on provided URL
  InvenTreeStatusCode _get_status_class(String url) {
    if (!_status_codes.containsKey(url)) {
      _status_codes[url] = InvenTreeStatusCode(url);
    }

    return _status_codes[url]!;
  }

  // Accessors methods for various status code classes
  InvenTreeStatusCode get StockHistoryStatus => _get_status_class("stock/track/status/");
  InvenTreeStatusCode get StockStatus => _get_status_class("stock/status/");
  InvenTreeStatusCode get PurchaseOrderStatus => _get_status_class("order/po/status/");
  InvenTreeStatusCode get SalesOrderStatus => _get_status_class("order/so/status/");

  void clearStatusCodeData() {
    StockHistoryStatus.data.clear();
    StockStatus.data.clear();
    PurchaseOrderStatus.data.clear();
    SalesOrderStatus.data.clear();
  }

  Future<void> fetchStatusCodeData({bool forceReload = true}) async {
    StockHistoryStatus.load(forceReload: forceReload);
    StockStatus.load(forceReload: forceReload);
    PurchaseOrderStatus.load(forceReload: forceReload);
    SalesOrderStatus.load(forceReload: forceReload);
  }

  int notification_counter = 0;

  Timer? _notification_timer;

  /*
   * Update notification counter (called periodically)
   */
  Future<void> _refreshNotifications() async {
    if (!isConnected()) {
      return;
    }

    if (!supportsNotifications) {
      return;
    }

    InvenTreeNotification().count(filters: {"read": "false"}).then((int n) {
      notification_counter = n;
    });
  }
}


