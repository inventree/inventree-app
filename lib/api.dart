import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:http/io_client.dart";
import "package:intl/intl.dart";
import "package:inventree/main.dart";
import "package:inventree/widget/progress.dart";
import "package:one_context/one_context.dart";
import "package:open_filex/open_filex.dart";
import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:flutter_cache_manager/flutter_cache_manager.dart";
import "package:path_provider/path_provider.dart";

import "package:inventree/api_form.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/auth/session_store.dart";
import "package:inventree/preferences.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/notification.dart";
import "package:inventree/inventree/status_codes.dart";
import "package:inventree/inventree/redact.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/settings/login.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Class representing an API response from the server
 */
class APIResponse {
  APIResponse({
    this.url = "",
    this.method = "",
    this.statusCode = -1,
    this.error = "",
    this.data = const {},
  });

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
    if (client != null) {
      // Shared client - certificate handling is already configured by its owner.
      // Overriding the callback here would discard per-profile certificate trust.
      _client = client;
    } else {
      _client = HttpClient();

      _client.badCertificateCallback = (cert, host, port) {
        return !strictHttps;
      };
    }
  }

  late final HttpClient _client;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final Uri resolved = Uri.base.resolve(url);

    final HttpClientRequest req = await _client.getUrl(resolved);

    if (headers != null) {
      headers.forEach((key, value) {
        req.headers.add(key, value);
      });
    }

    final HttpClientResponse httpResponse = await req.close();

    final http.StreamedResponse _response = http.StreamedResponse(
      httpResponse.timeout(Duration(seconds: 60)),
      httpResponse.statusCode,
      contentLength: httpResponse.contentLength < 0
          ? 0
          : httpResponse.contentLength,
      reasonPhrase: httpResponse.reasonPhrase,
      isRedirect: httpResponse.isRedirect,
    );

    return HttpGetResponse(_response);
  }
}

/*
 * InvenTree API - Access to the InvenTree REST interface.
 *
 * Requests are authenticated using a server session (cookie based),
 * which is established by logging in via the allauth API (see lib/auth/).
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
  // Session authentication requires the allauth "headless" API
  // Ref: https://github.com/inventree/InvenTree/pull/6293
  static const _minApiVersion = 314;

  bool _strictHttps = false;

  static const _URL_ROLES = "user/me/roles/";
  static const _URL_ME = "user/me/";

  // Accessors for various url endpoints
  String get baseUrl {
    String url = profile?.server ?? "";

    if (!url.endsWith("/")) {
      url += "/";
    }

    return url;
  }

  // Resolve a relative or absolute URL
  String _makeUrl(String url, {String base = ""}) {
    final baseUri = Uri.parse(base.isNotEmpty ? base : baseUrl);
    final pathUri = Uri.parse(url);

    // If path is absolute (has scheme), ignore base
    if (pathUri.hasScheme) {
      return pathUri.toString();
    }

    return baseUri.resolveUri(pathUri).toString();
  }

  String makeApiUrl(String endpoint) {
    String apiBase = makeUrl("/api/");

    return _makeUrl(endpoint, base: apiBase);
  }

  String get apiUrl => makeApiUrl("");

  String makeUrl(String endpoint) => _makeUrl(endpoint);

  UserProfile? profile;

  // Available user roles are loaded when connecting to the server
  Map<String, dynamic> roles = {};

  // Available user permissions are loaded when connecting to the server
  Map<String, dynamic> permissions = {};

  // Session cookies for the active profile
  SessionStore session = SessionStore();

  bool get hasSession => session.hasSession;

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
        icon: TablerIcons.server,
      );

      return false;
    }

    // Finally
    return true;
  }

  // Map of user information
  Map<String, dynamic> userInfo = {};

  String get username => (userInfo["username"] ?? "") as String;
  String get userEmail => (userInfo["email"] ?? "") as String;
  String get userFirstName => (userInfo["first_name"] ?? "") as String;
  String get userLastName => (userInfo["last_name"] ?? "") as String;

  int get userId => (userInfo["pk"] ?? -1) as int;

  // Map of server information
  Map<String, dynamic> serverInfo = {};

  String get serverInstance => (serverInfo["instance"] ?? "") as String;
  String get serverVersion => (serverInfo["version"] ?? "") as String;
  int get apiVersion => (serverInfo["apiVersion"] ?? 1) as int;

  /* API Version Checks
   * These functions are used to determine if the server supports a particular feature
   */

  // Does the server support "active" status on Company and SupplierPart API endpoints?
  bool get supportsCompanyActiveStatus => apiVersion >= 189;

  // Does the server support the "modern" (consolidated) label printing API?
  bool get supportsModernLabelPrinting => apiVersion >= 201;

  // Does the server support the "modern" (consolidated) attachment API?
  // Ref: https://github.com/inventree/InvenTree/pull/7420
  bool get supportsModernAttachments => apiVersion >= 207;

  bool get supportsUserPermissions => apiVersion >= 207;

  // Ref: https://github.com/inventree/InvenTree/pull/7514
  bool get supportsTopLevelFiltering => apiVersion >= 209;

  // Does the server support the "destination" field on the PurchaseOrder model?
  // Ref: https://github.com/inventree/InvenTree/pull/8403
  bool get supportsPurchaseOrderDestination => apiVersion >= 276;

  // Does the server support the "start_date" field for orders?
  // Ref: https://github.com/inventree/InvenTree/pull/8966
  bool get supportsStartDate => apiVersion >= 306;

  // Supports separate search against "supplier" / "customer" / "manufacturer"
  bool get supportsSplitCompanySearch => apiVersion >= 315;

  // Supports "requirements" information for specific part
  bool get supportsPartRequirements => apiVersion >= 350;

  // Does the server support the "modern" (consolidated) parameter API?
  // Ref: https://github.com/inventree/InvenTree/pull/10699
  bool get supportsModernParameters => apiVersion >= 429;

  // Does the support support the "primary" field on SupplierPart model?
  bool get supportsSupplierPartPrimaryField => apiVersion >= 456;

  // Does the server use the new "user/me/" endpoints?
  // Ref: https://github.com/inventree/InvenTree/pull/11963
  bool get supportsNewUserEndpoints => apiVersion >= 490;

  // Does the server support TransferOrder model
  // Ref: https://github.com/inventree/InvenTree/pull/11281
  bool get supportsTransferOrders => apiVersion >= 492;

  // Does the server support the "creation_date" field on the StockItem model?
  // Ref: https://github.com/inventree/InvenTree/pull/12011
  bool get supportsStockItemCreationDate => apiVersion >= 496;

  // Does the server support the "multi notes" API?
  // (Multiple HTML notes may be attached to a single model instance)
  // Ref: https://github.com/inventree/InvenTree/pull/11971
  bool get supportsMultiNotes => apiVersion >= 537;

  // Does the server support the "pricing" user role?
  // (Pricing endpoints also moved to the /api/pricing/ namespace)
  // Ref: https://github.com/inventree/InvenTree/pull/13034
  bool get supportsPricingRole => apiVersion >= 562;

  // Can the current user view part pricing information?
  // Older servers do not have a separate "pricing" role, so no check is performed
  bool get canViewPricing =>
      !supportsPricingRole || checkRole("pricing", "view");

  // Does the server support the "AuditLog" model?
  // Ref: https://github.com/inventree/InvenTree/pull/13069
  // Ref: https://github.com/inventree/InvenTree/pull/13101
  bool get supportsAuditLog => apiVersion >= 566;

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
    return profile != null && _connected && baseUrl.isNotEmpty && hasSession;
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
   * 2. If no session available, exit (user must login)
   * 3. Check the api/user/me/ endpoint to see if the session is valid
   * 4. If not authenticated, purge the session, and exit
   * 5. Request user roles
   * 6. Request information on available plugins
   */
  Future<bool> _connectToServer() async {
    if (!await checkServer()) {
      return false;
    }

    if (!hasSession) {
      return false;
    }

    final APIResponse authResponse = await _checkAuth();

    if (!authResponse.successful()) {
      await _handleAuthFailure(authResponse);
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
   * The user/me/ request failed - determine why, and what to do about it
   */
  Future<void> _handleAuthFailure(APIResponse response) async {
    final UserProfile? expiredProfile = profile;

    // Not an authentication problem (e.g. network error, server error)
    // Retain the session, as it may still be valid
    if (response.statusCode != 401 && response.statusCode != 403) {
      if (response.isValid()) {
        showStatusCodeError(_URL_ME, response.statusCode);
      }
      return;
    }

    // The server requires MFA to be configured for this user,
    // which must be done via the web interface
    if (response.asMap()["id"] == FLOW_MFA_REGISTER) {
      String detail = L10().mfaRegistrationRequiredDetail;

      final String serverMessage = (response.asMap()["error"] ?? "").toString();

      if (serverMessage.isNotEmpty) {
        detail = "${serverMessage}\n\n${detail}";
      }

      // End the (restricted) server session
      await delete("auth/v1/auth/session");

      await _expireSession(expiredProfile);

      _showAuthError(L10().mfaRegistrationRequired, detail);

      // Logging in again will not help - but suppress errors from other requests
      _loginRequired = true;
      return;
    }

    await _expireSession(expiredProfile);

    if (expiredProfile != null) {
      _showAuthError(
        L10().sessionExpired,
        "${L10().sessionExpiredDetail}\n${expiredProfile.name}",
      );

      // Take the user straight to the login screen for this profile,
      // rather than leaving them to work out why Home shows disconnected
      _requestLogin(expiredProfile);
    } else {
      showServerError(
        _URL_ME,
        L10().serverNotConnected,
        L10().serverAuthenticationError,
      );
    }
  }

  // Pending check of whether the session is still valid (see _handleUnauthorized).
  // Requests rejected while the check is running share its result
  Future<bool>? _sessionCheck;

  // Zone value which identifies the session check request itself
  static const Symbol _SESSION_CHECK_ZONE = #inventreeSessionCheck;

  // Set once the session has been found to be invalid, until the user logs in
  // again (or leaves the login screen)
  bool _loginRequired = false;

  // Set while the login screen is open (opened by _requestLogin)
  bool _loginScreenOpen = false;

  // Set while displaying the reason for an authentication failure
  bool _showingAuthError = false;

  /*
   * Errors caused by an expired session are not displayed to the user -
   * they are directed to the login screen instead.
   * Checked by showServerError() before displaying an error.
   *
   * Only applies once the session is known to be invalid - requests rejected
   * while the session is being checked wait for the result (_handleUnauthorized)
   */
  bool get suppressServerErrors => _loginRequired && !_showingAuthError;

  void _showAuthError(String title, String description) {
    _showingAuthError = true;

    try {
      showServerError(_URL_ME, title, description);
    } finally {
      _showingAuthError = false;
    }
  }

  /*
   * Take the user to the login screen for the provided profile
   * (unless it is already open)
   */
  void _requestLogin(UserProfile? prf) {
    _loginRequired = true;

    if (prf == null || _loginScreenOpen) {
      return;
    }

    _loginScreenOpen = true;

    debug("API : Opening login screen for '${prf.name}'");

    if (hasContext()) {
      OneContext()
          .push(
            MaterialPageRoute(builder: (context) => InvenTreeLoginWidget(prf)),
          )
          .then((_) => onLoginScreenClosed());
    }
  }

  /*
   * The login screen was closed (logged in, or dismissed by the user).
   * If the user did not login, the next rejected request opens it again
   */
  @visibleForTesting
  void onLoginScreenClosed() {
    _loginScreenOpen = false;
    _loginRequired = false;
  }

  /*
   * Return true if a response for [uri] indicates that authentication failed
   * (e.g. the session has expired, or was ended from the web interface).
   *
   * Responses from the allauth endpoints are excluded - these return 401
   * as part of normal operation (e.g. logout, pending login flows)
   */
  bool _isUnauthorized(Uri uri, int statusCode) {
    if (statusCode != 401 || !session.isServerUri(uri)) {
      return false;
    }

    return !uri.path.contains("/api/auth/");
  }

  /*
   * A request was rejected with 401.
   *
   * If connected, confirm that the session is no longer valid (a single request
   * could be rejected for other reasons), and if so, end the connection and take
   * the user to the login screen. If not connected (e.g. a screen which was open
   * when the session expired), take the user to the login screen.
   *
   * Returns true if the failure has been handled, and should not be reported
   * to the user as an error.
   */
  Future<bool> _handleUnauthorized(String url) async {
    // The connection routine reports authentication problems itself
    if (_connecting) {
      return false;
    }

    // This is the session check request itself - the check handles the result
    // (waiting for the check here would never complete)
    if (Zone.current[_SESSION_CHECK_ZONE] == true) {
      return false;
    }

    // Another request is already checking the session - share its result,
    // so this request is only treated as handled if login is actually required
    final Future<bool>? pending = _sessionCheck;

    if (pending != null) {
      return pending;
    }

    if (!_connected) {
      if (!_loginRequired) {
        _requestLogin(profile);
      }

      return true;
    }

    final Future<bool> check = _checkSession();
    _sessionCheck = check;

    try {
      return await check;
    } finally {
      if (identical(_sessionCheck, check)) {
        _sessionCheck = null;
      }
    }
  }

  /*
   * Check whether the session is still valid (after a request was rejected).
   * If not, expire the session and direct the user to login again.
   *
   * Returns true if the session has expired (login is required).
   */
  Future<bool> _checkSession() async {
    // Run the request in a zone which identifies it as the session check
    final APIResponse response = await runZoned(
      _checkAuth,
      zoneValues: {_SESSION_CHECK_ZONE: true},
    );

    if (response.statusCode != 401 && response.statusCode != 403) {
      // Session is still valid (or the server could not be reached),
      // so report the original error as normal
      return false;
    }

    debug("API : Session expired while connected");

    // The user is no longer authenticated
    userInfo = {};

    // Expire the session and direct the user to login again
    await _handleAuthFailure(response);

    _connected = false;
    _notification_timer?.cancel();
    _notification_timer = null;
    _connectionStatusChanged();

    return true;
  }

  // Mark a response which was rejected because the user must login again
  // (so that it is not reported as an error - see reportModelError)
  void _markLoginRequired(APIResponse response) {
    response.error = "LoginRequired";
    response.errorDetail = L10().sessionExpired;
  }

  /*
   * Discard the session and CSRF cookies for the provided profile.
   * Other cookies (e.g. MFA "trusted device") are retained.
   */
  Future<void> _expireSession(UserProfile? prf) async {
    session.clearAuthCookies();

    if (prf != null) {
      // The session is no longer valid on the server, so a stored copy cannot
      // be used to reconnect - but it should still not be left in storage
      if (!await UserProfileDBManager().removeStoredSession(prf, session)) {
        debug("API : Expired session could not be removed from storage");
      }

      prf.hasSession = false;
    }
  }

  /*
   * Check that the remote server is available.
   * Ping the api/ endpoint, which does not require user authentication
   */
  Future<bool> checkServer({String? server}) async {
    String address = server ?? profile?.server ?? "";

    if (address.isEmpty) {
      showSnackIcon(
        L10().incompleteDetails,
        icon: TablerIcons.exclamation_circle,
        success: false,
      );
      return false;
    }

    String url = _makeUrl("/api/", base: address);

    if (!url.endsWith("/")) {
      url = url + "/";
    }

    await _refreshHttpsPolicy();

    debug("Connecting to ${apiUrl}");

    APIResponse response = await get(url, expectedStatusCode: 200);

    if (!response.successful()) {
      debug("Server returned invalid response: ${response.statusCode}");
      showStatusCodeError(apiUrl, response.statusCode, details: response.data);
      return false;
    }

    Map<String, dynamic> _data = response.asMap();

    serverInfo = {..._data};

    if (serverVersion.isEmpty) {
      showServerError(apiUrl, L10().missingData, L10().serverMissingData);

      return false;
    }

    if (apiVersion < _minApiVersion) {
      String message = L10().serverApiVersion + ": ${apiVersion}";

      message += "\n";
      message += L10().serverApiRequired + ": ${_minApiVersion}";

      message += "\n\n";

      message += "Ensure your InvenTree server version is up to date!";

      showServerError(apiUrl, L10().serverOld, message);

      return false;
    }

    // At this point, we have a server which is responding
    return true;
  }

  /*
   * Check that the user is authenticated
   * Fetch the user information
   *
   * The user information is only replaced if the check succeeds - a failed check
   * (e.g. network error while connected) must not discard the current identity.
   * It is cleared on disconnect, and when the session expires.
   */
  Future<APIResponse> _checkAuth() async {
    debug("Checking user auth @ ${_URL_ME}");

    // Do not display an error for an unexpected status code here,
    // the caller determines what to show the user
    final response = await get(_URL_ME, expectedStatusCode: null);

    if (response.successful() && response.statusCode == 200) {
      userInfo = response.asMap();
    } else {
      debug(
        "Auth request failed: Server returned status ${response.statusCode}",
      );
      if (response.data != null) {
        debug("Server response: ${response.data.toString()}");
      }
    }

    return response;
  }

  /*
   * Prepare to authenticate against the server for the provided profile.
   * Any stored session / CSRF cookies are discarded (in memory only),
   * but other cookies (e.g. MFA "trusted device") are retained.
   * The session is not persisted until authentication succeeds (see InvenTreeAuth).
   */
  Future<void> beginAuthentication(UserProfile userProfile) async {
    disconnectFromServer();

    final SessionStore store = await UserProfileDBManager().loadSession(
      userProfile,
    );

    store.clearAuthCookies();

    profile = userProfile;
    session = store;

    await _refreshHttpsPolicy();
  }

  void disconnectFromServer() {
    debug("API : disconnectFromServer()");

    _connected = false;
    _connecting = false;
    _loginRequired = false;
    profile = null;

    // Drop the in-memory session (it remains in secure storage)
    session.onChanged = null;
    session = SessionStore();

    _resetHttpClient();

    // Clear received settings
    _globalSettings.clear();
    _userSettings.clear();

    roles.clear();
    _plugins.clear();
    serverInfo.clear();
    userInfo = {};
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
        icon: TablerIcons.exclamation_circle,
      );
      return false;
    }

    // Load the stored session, and persist any changes the server makes to it
    final SessionStore store = await UserProfileDBManager().loadSession(prf);

    store.onChanged = () {
      UserProfileDBManager().saveSession(prf, store);
    };

    session = store;

    // Cancel notification timer
    _notification_timer?.cancel();
    _notification_timer = null;

    _connecting = true;
    _connectionStatusChanged();

    // Perform the actual connection routine
    _connected = await _connectToServer();
    _connecting = false;

    if (_connected) {
      _loginScreenOpen = false;

      showSnackIcon(
        L10().serverConnected,
        icon: TablerIcons.server,
        success: true,
      );

      if (_notification_timer == null) {
        debug("starting notification timer");
        _notification_timer = Timer.periodic(Duration(seconds: 60), (timer) {
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
    String actualRoleUrl = supportsNewUserEndpoints
        ? _URL_ROLES
        : "user/roles/";
    final response = await get(actualRoleUrl, expectedStatusCode: 200);

    if (!response.successful()) {
      return false;
    }

    var data = response.asMap();

    if (!data.containsKey("roles")) {
      roles = {};
      permissions = {};

      showServerError(apiUrl, L10().serverError, L10().errorUserRoles);
      return false;
    }

    roles = (data["roles"] ?? {}) as Map<String, dynamic>;

    if (supportsUserPermissions && data.containsKey("permissions")) {
      permissions = (data["permissions"] ?? {}) as Map<String, dynamic>;
    } else {
      permissions = {};
    }

    return true;
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
   * e.g. "sales_order", "change"
   */
  bool checkRole(String role, String permission) {
    if (!_connected) {
      return false;
    }

    // If we do not have enough information, assume permission is allowed
    if (roles.isEmpty) {
      debug("checkRole - no roles defined!");
      return true;
    }

    if (!roles.containsKey(role)) {
      debug("checkRole - role '$role' not found!");
      return true;
    }

    if (roles[role] == null) {
      debug("checkRole - role '$role' is null!");
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
          "api.checkRole",
          error,
          stackTrace,
          context: {
            "role": role,
            "permission": permission,
            "error": error.toString(),
          },
        );
      }

      // Unable to determine permission - assume true?
      return true;
    }
  }

  /*
   * Check if the user has the particular model permission assigned
   * e.g. "company", "add"
   */
  bool checkPermission(String model, String permission) {
    if (!_connected) {
      return false;
    }

    if (permissions.isEmpty) {
      // Not enough information available - default to True
      return true;
    }

    if (!permissions.containsKey(model)) {
      debug("checkPermission - model '$model' not found!");
      return false;
    }

    if (permissions[model] == null) {
      debug("checkPermission - model '$model' is null!");
      return false;
    }

    try {
      List<String> perms = List.from(permissions[model] as List<dynamic>);
      return perms.contains(permission);
    } catch (error, stackTrace) {
      if (error is TypeError) {
        // Ignore TypeError
      } else {
        // Unknown error - report it!
        sentryReportError(
          "api.checkPermission",
          error,
          stackTrace,
          context: {
            "model": model,
            "permission": permission,
            "error": error.toString(),
          },
        );
      }

      // Unable to determine permission - assume true?
      return true;
    }
  }

  // Perform a PATCH request
  Future<APIResponse> patch(
    String url, {
    Map<String, dynamic> body = const {},
    int? expectedStatusCode,
  }) async {
    Map<String, dynamic> _body = body;

    HttpClientRequest? request = await apiRequest(url, "PATCH");

    if (request == null) {
      // Return an "invalid" APIResponse
      return APIResponse(
        url: url,
        method: "PATCH",
        error: "HttpClientRequest is null",
      );
    }

    return completeRequest(
      request,
      data: json.encode(_body),
      statusCode: expectedStatusCode,
    );
  }

  /*
   * Download a file from the given URL
   */
  Future<void> downloadFile(String url, {bool openOnDownload = true}) async {
    if (url.isEmpty) {
      // No URL provided for download
      return;
    }

    // Find the local downloads directory
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

    showLoadingOverlay();

    // Attempt to open a connection to the server
    try {
      _request = await httpClient
          .openUrl("GET", _uri)
          .timeout(Duration(seconds: 10));

      // Set headers
      defaultHeaders(url: _uri.toString()).forEach((key, value) {
        _request?.headers.set(key, value);
      });
    } on SocketException catch (error) {
      debug("SocketException at ${url}: ${error.toString()}");
      showServerError(
        url,
        L10().connectionRefused,
        L10().connectionRefusedDetail,
      );
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
      sentryReportError("api.downloadFile : client.openUrl", error, stackTrace);
      return;
    }

    try {
      final response = await _request.close();

      if (response.statusCode == 200) {
        var bytes = await consolidateHttpClientResponseBytes(response);

        File localFile = File(local_path);

        await localFile.writeAsBytes(bytes);

        if (openOnDownload) {
          hideLoadingOverlay();
          OpenFilex.open(local_path);
        }
      } else if (_isUnauthorized(_uri, response.statusCode) &&
          await _handleUnauthorized(url)) {
        // User has been directed to login, rather than shown an error
        hideLoadingOverlay();
      } else {
        showStatusCodeError(url, response.statusCode);
      }
    } on SocketException {
      showServerError(
        url,
        L10().connectionRefused,
        L10().connectionRefusedDetail,
      );
    } on TimeoutException {
      showTimeoutError(url);
    } catch (error, stackTrace) {
      debug("Error downloading image:");
      debug(error.toString());
      showServerError(url, L10().downloadError, error.toString());
      sentryReportError(
        "api.downloadFile : client.closeRequest",
        error,
        stackTrace,
      );
    }

    hideLoadingOverlay();
  }

  /*
   * Upload a file to the given URL
   */
  Future<APIResponse> uploadFile(
    String url,
    File f, {
    String name = "attachment",
    String method = "POST",
    Map<String, dynamic>? fields,
  }) async {
    final uri = Uri.parse(makeApiUrl(url));
    final request = http.MultipartRequest(method, uri);

    // Default headers
    defaultHeaders(method: method, url: uri.toString()).forEach((key, value) {
      request.headers[key] = value;
    });

    // Optional fields
    if (fields != null) {
      fields.forEach((String key, dynamic value) {
        if (value == null) {
          request.fields[key] = "";
        } else {
          request.fields[key] = value.toString();
        }
      });
    }

    // Add file to upload
    var _file = await http.MultipartFile.fromPath(name, f.path);
    request.files.add(_file);

    // Construct a response object to return
    APIResponse response = APIResponse(url: url, method: method);

    String jsondata = "";

    try {
      var streamedResponse = await IOClient(
        httpClient,
      ).send(request).timeout(Duration(seconds: 120));
      final httpResponse = await http.Response.fromStream(streamedResponse);

      response.statusCode = httpResponse.statusCode;

      // package:http folds multiple Set-Cookie headers into a single value
      final String? setCookie = httpResponse.headers["set-cookie"];

      if (setCookie != null) {
        session.captureHeaders(uri, splitSetCookieHeader(setCookie));
      }

      jsondata = httpResponse.body;

      // Report a server-side error
      if (response.statusCode == 500) {
        sentryReportMessage(
          "Server error in uploadFile()",
          context: {
            "url": url,
            "method": request.method,
            "name": name,
            "statusCode": response.statusCode.toString(),
            "requestHeaders": redactHeaders(request.headers),
            "responseHeaders": redactHeaders(httpResponse.headers),
            "responseData": _truncate(httpResponse.body),
          },
        );
      }

      try {
        response.data = json.decode(jsondata);
      } on FormatException {
        // An authentication failure may not have a JSON body (e.g. empty,
        // or an HTML page from a proxy) - it is handled below, rather than
        // reported as an invalid response
        if (!_isUnauthorized(uri, response.statusCode)) {
          rethrow;
        }

        response.data = {};
      }

      if (_isUnauthorized(uri, response.statusCode) &&
          await _handleUnauthorized(url)) {
        _markLoginRequired(response);
      }
    } on SocketException catch (error) {
      showServerError(
        url,
        L10().connectionRefused,
        L10().connectionRefusedDetail,
      );
      response.error = "SocketException";
      response.errorDetail = error.toString();
    } on FormatException {
      showServerError(
        url,
        L10().formatException,
        L10().formatExceptionJson + ":\n${jsondata}",
      );

      // Server errors have already been reported (including the response data)
      if (response.statusCode < 500) {
        sentryReportMessage(
          "Error decoding JSON response from server",
          context: {
            "method": "uploadFile",
            "url": url,
            "statusCode": response.statusCode.toString(),
            "data": jsondata,
          },
        );
      }
    } on TimeoutException {
      showTimeoutError(url);
      response.error = "TimeoutException";
    } catch (error, stackTrace) {
      showServerError(url, L10().serverError, error.toString());
      sentryReportError("api.uploadFile", error, stackTrace);
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
  Future<APIResponse> options(
    String url, {
    Map<String, String> params = const {},
  }) async {
    HttpClientRequest? request = await apiRequest(
      url,
      "OPTIONS",
      urlParams: params,
    );

    if (request == null) {
      // Return an "invalid" APIResponse
      return APIResponse(url: url, method: "OPTIONS");
    }

    return completeRequest(request);
  }

  /*
   * Perform a HTTP POST request
   * Returns a json object (or null if unsuccessful)
   */
  Future<APIResponse> post(
    String url, {
    Map<String, dynamic> body = const {},
    int? expectedStatusCode = 201,
  }) async {
    HttpClientRequest? request = await apiRequest(url, "POST");

    if (request == null) {
      // Return an "invalid" APIResponse
      return APIResponse(url: url, method: "POST");
    }

    return completeRequest(
      request,
      data: json.encode(body),
      statusCode: expectedStatusCode,
    );
  }

  /*
   * Perform a request to link a custom barcode to a particular item
   */
  Future<bool> linkBarcode(Map<String, String> body) async {
    HttpClientRequest? request = await apiRequest("barcode/link/", "POST");

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

  /*
   * Perform a request to unlink a custom barcode from a particular item
   */
  Future<bool> unlinkBarcode(Map<String, dynamic> body) async {
    HttpClientRequest? request = await apiRequest("barcode/unlink/", "POST");

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

  /*
   * Create a new HttpClient, with the appropriate certificate handling
   * Note that for some instances, we may wish to ignore certificate errors (e.g. self-signed certificates)
   * In this case, we will allow the user to disable "strict HTTPS" mode
   */
  HttpClient _createClient() {
    HttpClient client = HttpClient();

    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          // The active profile may have been explicitly trusted by the user
          // (in-flow, after a prior certificate failure) - honor that first
          if (profile?.trustedCertificate ?? false) {
            return true;
          }

          if (_strictHttps) {
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
   * Cached, reusable HttpClient instance.
   * Avoids doing a slow TCP + TLS handshake on each request.
   */
  HttpClient? _httpClient;

  HttpClient get httpClient {
    return _httpClient ??= _createClient();
  }

  void _resetHttpClient() {
    _httpClient?.close(force: true);
    _httpClient = null;
    _imageCacheManager = null;
  }

  /*
   * Notify the API that the "strictHttps" setting has been changed.
   */
  void onStrictHttpsChanged(bool strictHttps) {
    if (strictHttps != _strictHttps) {
      _strictHttps = strictHttps;
      _resetHttpClient();
    }
  }

  Future<void> _refreshHttpsPolicy() async {
    final bool strictHttps =
        await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false)
            as bool;

    onStrictHttpsChanged(strictHttps);
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
    String method, {
    Map<String, String> urlParams = const {},
    Map<String, String> headers = const {},
  }) async {
    var _url = makeApiUrl(url);

    if (_url.isEmpty) {
      showServerError(url, L10().invalidHost, L10().invalidHostDetails);
      return null;
    }

    Uri? _uri = Uri.tryParse(_url);

    if (_uri == null || _uri.host.isEmpty) {
      showServerError(_url, L10().invalidHost, L10().invalidHostDetails);
      return null;
    }

    // Add any required query parameters to the URL (merged with any already present).
    // Values are URL encoded - e.g. a search for "M3 & M4" or "C++"
    if (urlParams.isNotEmpty) {
      _uri = _uri.replace(
        queryParameters: <String, dynamic>{
          ..._uri.queryParametersAll,
          ...urlParams,
        },
      );
    }

    HttpClientRequest? _request;

    // Attempt to open a connection to the server
    // (retries once after a short delay on a transient network blip -
    // nothing has been sent yet at this point, so a retry here is safe)
    try {
      _request = await _openUrlWithRetry(method, _uri);

      // Default headers
      defaultHeaders(method: method, url: _uri.toString()).forEach((
        key,
        value,
      ) {
        _request?.headers.set(key, value);
      });

      // Custom headers
      headers.forEach((key, value) {
        _request?.headers.set(key, value);
      });

      return _request;
    } on SocketException catch (error) {
      debug("SocketException at ${url}: ${error.toString()}");
      showServerError(
        url,
        L10().connectionRefused,
        L10().connectionRefusedDetail,
      );
      return null;
    } on TimeoutException {
      debug("TimeoutException at ${url}");
      showTimeoutError(url);
      return null;
    } on OSError catch (error) {
      debug("OSError at ${url}: ${error.toString()}");
      showServerError(
        url,
        L10().connectionRefused,
        L10().connectionRefusedDetail,
      );
      return null;
    } on CertificateException catch (error) {
      final HttpClientRequest? retried = await _retryAfterCertificateTrust(
        url,
        method,
        _uri,
        headers,
      );
      if (retried != null) {
        return retried;
      }
      debug("CertificateException at ${url}:");
      debug(error.toString());
      showServerError(url, L10().serverCertificateError, error.toString());
      return null;
    } on HandshakeException catch (error) {
      final HttpClientRequest? retried = await _retryAfterCertificateTrust(
        url,
        method,
        _uri,
        headers,
      );
      if (retried != null) {
        return retried;
      }
      debug("HandshakeException at ${url}:");
      debug(error.toString());
      showServerError(url, L10().serverCertificateError, error.toString());
      return null;
    } catch (error, stackTrace) {
      debug("Server error at ${url}: ${error.toString()}");
      showServerError(url, L10().serverError, error.toString());
      sentryReportError(
        "api.apiRequest : openUrl",
        error,
        stackTrace,
        context: {"url": url, "method": method},
      );

      return null;
    }
  }

  /*
   * Open a connection to the given URL, retrying once after a short delay
   * if the first attempt fails with a transient network error. Nothing has
   * been sent to the server yet at this point, so a retry here is safe
   * regardless of HTTP method (unlike retrying after a response has already
   * started being read/sent).
   */
  Future<HttpClientRequest> _openUrlWithRetry(String method, Uri uri) async {
    try {
      return await httpClient
          .openUrl(method, uri)
          .timeout(Duration(seconds: 10));
    } on SocketException {
      await Future.delayed(const Duration(seconds: 2));
      return await httpClient
          .openUrl(method, uri)
          .timeout(Duration(seconds: 10));
    } on TimeoutException {
      await Future.delayed(const Duration(seconds: 2));
      return await httpClient
          .openUrl(method, uri)
          .timeout(Duration(seconds: 10));
    }
  }

  /*
   * A certificate error occurred while connecting to the active profile's
   * server. If the user hasn't already trusted this profile's certificate,
   * prompt them in-flow; if they accept, persist that decision against the
   * profile and retry the connection once.
   */
  Future<HttpClientRequest?> _retryAfterCertificateTrust(
    String url,
    String method,
    Uri uri,
    Map<String, String> headers,
  ) async {
    final UserProfile? prf = profile;

    if (prf == null || prf.trustedCertificate) {
      // Nothing new to prompt for - surface the original error as-is
      return null;
    }

    final bool trust = await _promptTrustCertificate(uri.host);

    if (!trust) {
      return null;
    }

    prf.trustedCertificate = true;
    await UserProfileDBManager().updateProfile(prf);

    try {
      final HttpClientRequest request = await httpClient
          .openUrl(method, uri)
          .timeout(Duration(seconds: 10));

      defaultHeaders(method: method, url: uri.toString()).forEach((key, value) {
        request.headers.set(key, value);
      });

      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      return request;
    } catch (error) {
      debug(
        "Retry after certificate trust failed at ${url}: ${error.toString()}",
      );
      return null;
    }
  }

  /*
   * Ask the user whether to trust an otherwise-invalid TLS certificate for
   * the given host. Returns true if they accept.
   */
  Future<bool> _promptTrustCertificate(String host) async {
    final Completer<bool> completer = Completer<bool>();

    confirmationDialog(
      L10().serverCertificateError,
      "${L10().serverCertificateTrust}\n${host}",
      icon: TablerIcons.shield_exclamation,
      onAccept: () {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onReject: () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    return completer.future;
  }

  /*
   * Complete an API request, and return an APIResponse object
   */
  Future<APIResponse> completeRequest(
    HttpClientRequest request, {
    String? data,
    int? statusCode,
    bool ignoreResponse = false,
  }) async {
    if (data != null && data.isNotEmpty) {
      var encoded_data = utf8.encode(data);

      request.headers.set(
        HttpHeaders.contentLengthHeader,
        encoded_data.length.toString(),
      );
      request.add(encoded_data);
    }

    APIResponse response = APIResponse(
      method: request.method,
      url: request.uri.toString(),
    );

    String url = request.uri.toString();

    try {
      HttpClientResponse? _response = await request.close().timeout(
        Duration(seconds: 10),
      );

      response.statusCode = _response.statusCode;

      // Store any cookies provided by the server (e.g. session, CSRF token)
      session.captureHeaders(
        request.uri,
        _response.headers[HttpHeaders.setCookieHeader],
      );

      // If the server returns a server error code, alert the user
      if (_response.statusCode >= 500) {
        // Read the response body, which may describe the error
        // (not necessarily JSON - e.g. an HTML error page from a proxy)
        final String body = ignoreResponse
            ? ""
            : await _response
                  .transform(const Utf8Decoder(allowMalformed: true))
                  .join();

        try {
          response.data = body.isEmpty ? {} : json.decode(body) ?? {};
        } on FormatException {
          response.data = {};
        }

        showStatusCodeError(url, _response.statusCode, details: response.data);

        // Some server errors are not ones for us to worry about!
        switch (_response.statusCode) {
          case 502: // Bad gateway
          case 503: // Service unavailable
          case 504: // Gateway timeout
            break;
          default: // Any other error code
            sentryReportMessage(
              "Server error",
              context: {
                "url": request.uri.toString(),
                "method": request.method,
                "statusCode": _response.statusCode.toString(),
                "requestHeaders": redactHttpHeaders(request.headers),
                "responseHeaders": redactHttpHeaders(_response.headers),
                "responseData": _truncate(body),
              },
            );
        }
      } else {
        response.data = ignoreResponse
            ? {}
            : await responseToJson(url, _response) ?? {};

        if (_isUnauthorized(request.uri, _response.statusCode) &&
            await _handleUnauthorized(url)) {
          // User has been directed to login, rather than shown an error
          _markLoginRequired(response);
        } else if (statusCode != null && statusCode != _response.statusCode) {
          // Check that the returned status code is what we expected
          showStatusCodeError(
            url,
            _response.statusCode,
            details: response.data,
          );
        }
      }
    } on HttpException catch (error) {
      showServerError(url, L10().serverError, error.toString());
      response.error = "HTTPException";
      response.errorDetail = error.toString();
    } on SocketException catch (error) {
      showServerError(
        url,
        L10().connectionRefused,
        L10().connectionRefusedDetail,
      );
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

  // Limit the size of response data included in error reports
  String _truncate(String data, {int length = 2000}) =>
      data.length > length ? "${data.substring(0, length)}..." : data;

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
              "headers": redactHttpHeaders(response.headers),
              "statusCode": response.statusCode.toString(),
              "data": body.toString(),
              "endpoint": url,
            },
          );
      }

      // An authentication failure may not have a JSON body (e.g. from a proxy).
      // It is handled as such by the caller (see _handleUnauthorized),
      // rather than reported as an invalid response
      final Uri? uri = Uri.tryParse(url);

      if (uri == null || !_isUnauthorized(uri, response.statusCode)) {
        showServerError(
          url,
          L10().formatException,
          L10().formatExceptionJson + ":\n${body}",
        );
      }

      // Return an empty map
      return {};
    }
  }

  /*
   * Perform a HTTP GET request
   * Returns a json object (or null if did not complete)
   */
  Future<APIResponse> get(
    String url, {
    Map<String, String> params = const {},
    Map<String, String> headers = const {},
    int? expectedStatusCode = 200,
  }) async {
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
    HttpClientRequest? request = await apiRequest(url, "DELETE");

    if (request == null) {
      // Return an "invalid" APIResponse object
      return APIResponse(
        url: url,
        method: "DELETE",
        error: "HttpClientRequest is null",
      );
    }

    return completeRequest(request, ignoreResponse: true);
  }

  // Find the current locale code for the running app
  String get currentLocale {
    if (hasContext()) {
      // Try to get app context
      BuildContext? context = OneContext().context;

      if (context != null) {
        Locale? locale = InvenTreeApp.of(context)?.locale;

        if (locale != null) {
          return locale.languageCode; //.toString();
        }
      }
    }

    // Fallback value
    return Intl.getCurrentLocale();
  }

  // HTTP methods which require CSRF protection
  static const List<String> _unsafeMethods = ["POST", "PUT", "PATCH", "DELETE"];

  /*
   * Return a list of request headers.
   *
   * Session credentials (cookies, CSRF token) are only included
   * if [url] points at the active server - never for a foreign host.
   * If [url] is not provided, the request is assumed to be to the server.
   */
  Map<String, String> defaultHeaders({String method = "GET", String? url}) {
    Map<String, String> headers = {};

    headers[HttpHeaders.acceptHeader] = "application/json";
    headers[HttpHeaders.contentTypeHeader] = "application/json";
    headers[HttpHeaders.acceptLanguageHeader] = currentLocale;

    final Uri? target = Uri.tryParse(
      (url == null || url.isEmpty) ? baseUrl : makeUrl(url),
    );

    if (target == null || !session.isServerUri(target)) {
      return headers;
    }

    final String cookies = session.cookieHeader(target);

    if (cookies.isNotEmpty) {
      headers[HttpHeaders.cookieHeader] = cookies;
    }

    if (_unsafeMethods.contains(method.toUpperCase())) {
      if (session.hasCsrfToken) {
        headers["X-CSRFToken"] = session.csrfToken;
      }

      // Django CSRF protection checks the Origin (or Referer, for HTTPS)
      headers["Origin"] = target.origin;
      headers[HttpHeaders.refererHeader] = baseUrl;
    }

    return headers;
  }

  static String get staticImage => "/static/img/blank_image.png";

  static String get staticThumb => "/static/img/blank_image.thumbnail.png";

  CachedNetworkImage? getThumbnail(
    String imageUrl, {
    double size = 40,
    bool hideIfNull = false,
  }) {
    if (hideIfNull) {
      if (imageUrl.isEmpty) {
        return null;
      }
    }

    try {
      return getImage(imageUrl, width: size, height: size);
    } catch (error, stackTrace) {
      sentryReportError("_getThumbnail", error, stackTrace);
      return null;
    }
  }

  /*
   * Load image from the InvenTree server,
   * or from local cache (if it has been cached!)
   */
  CachedNetworkImage getImage(
    String imageUrl, {
    double? height,
    double? width,
  }) {
    if (imageUrl.isEmpty) {
      imageUrl = staticImage;
    }

    String url = makeUrl(imageUrl);

    return CachedNetworkImage(
      imageUrl: url,
      placeholder: (context, url) => CircularProgressIndicator(),
      errorWidget: (context, url, error) {
        print("CachedNetworkimage error: ${error.toString()}");
        return GestureDetector(
          child: Icon(TablerIcons.circle_x, color: COLOR_DANGER),
          onTap: () => {
            showSnackIcon(error.toString().split(",")[0], success: false),
          },
        );
      },
      httpHeaders: defaultHeaders(url: url),
      height: height,
      width: width,
      cacheManager: imageCacheManager,
    );
  }

  CacheManager? _imageCacheManager;

  CacheManager get imageCacheManager {
    return _imageCacheManager ??= CacheManager(
      Config(
        "inventree_network_image",
        fileService: InvenTreeFileService(
          client: httpClient,
          strictHttps: _strictHttps,
        ),
      ),
    );
  }

  // Keep a record of which settings we have received from the server
  Map<String, InvenTreeGlobalSetting> _globalSettings = {};
  Map<String, InvenTreeUserSetting> _userSettings = {};

  Future<String> getGlobalSetting(String key) async {
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
  Future<bool> getGlobalBooleanSetting(
    String key, {
    bool backup = false,
  }) async {
    String value = await getGlobalSetting(key);

    if (value.isEmpty) {
      return backup;
    }

    return value.toLowerCase().trim() == "true";
  }

  Future<String> getUserSetting(String key) async {
    InvenTreeUserSetting? setting = _userSettings[key];

    if ((setting != null) && setting.reloadedWithin(Duration(minutes: 5))) {
      return setting.value;
    }

    final response = await InvenTreeUserSetting().getModel(key);

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
    return value.toLowerCase().trim() == "true";
  }

  /*
   * Send a request to the server to locate / identify either a StockItem or StockLocation
   */
  Future<void> locateItemOrLocation(
    BuildContext context, {
    int? item,
    int? location,
  }) async {
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
        },
      };

      await launchApiForm(
        context,
        L10().locateLocation,
        "",
        fields,
        icon: TablerIcons.location_search,
        onSuccess: (Map<String, dynamic> data) async {
          plugin_name = (data["plugin"] ?? "") as String;
        },
      );
    }

    Map<String, dynamic> body = {"plugin": plugin_name};

    if (item != null) {
      body["item"] = item.toString();
    }

    if (location != null) {
      body["location"] = location.toString();
    }

    post("/api/locate/", body: body, expectedStatusCode: 200).then((
      APIResponse response,
    ) {
      if (response.successful()) {
        showSnackIcon(L10().requestSuccessful, success: true);
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
  InvenTreeStatusCode get StockStatus => _get_status_class("stock/status/");
  InvenTreeStatusCode get PurchaseOrderStatus =>
      _get_status_class("order/po/status/");
  InvenTreeStatusCode get SalesOrderStatus =>
      _get_status_class("order/so/status/");

  InvenTreeStatusCode get BuildOrderStatus =>
      _get_status_class("build/status/");

  void clearStatusCodeData() {
    StockStatus.data.clear();
    PurchaseOrderStatus.data.clear();
    SalesOrderStatus.data.clear();
    BuildOrderStatus.data.clear();
  }

  Future<void> fetchStatusCodeData({bool forceReload = true}) async {
    StockStatus.load(forceReload: forceReload);
    PurchaseOrderStatus.load(forceReload: forceReload);
    SalesOrderStatus.load(forceReload: forceReload);
    BuildOrderStatus.load(forceReload: forceReload);
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

    InvenTreeNotification().count(filters: {"read": "false"}).then((int n) {
      notification_counter = n;
    });
  }
}
