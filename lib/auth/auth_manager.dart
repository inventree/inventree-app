import "package:inventree/api.dart";
import "package:inventree/auth/allauth_client.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/auth/session_store.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";
import "package:inventree/user_profile.dart";

/*
 * Coordinates authentication against an InvenTree server.
 *
 * - Starts a login using an AuthMethod (e.g. username / password)
 * - Steps through any additional flows required by the server (e.g. MFA)
 * - Persists the resulting session cookies against the profile
 *
 * The UI only needs to react to the AuthResult returned by each step.
 */
class InvenTreeAuth {
  factory InvenTreeAuth() {
    return _instance;
  }

  InvenTreeAuth._internal();

  static final InvenTreeAuth _instance = InvenTreeAuth._internal();

  final AllauthClient client = const AllauthClient();

  // Profile which is currently being authenticated
  UserProfile? _profile;

  // Username used for the current login - saved against the profile on success
  String _username = "";

  /*
   * Start a new login for the provided profile
   */
  Future<AuthResult> beginLogin(UserProfile profile, AuthMethod method) async {
    final InvenTreeAPI api = InvenTreeAPI();

    _profile = profile;
    _username = method.username;

    debug("InvenTreeAuth: Starting login for ${profile.name}");

    await api.beginAuthentication(profile);

    // Check the server is available, and supports session authentication
    if (!await api.checkServer()) {
      return AuthResult.failed("");
    }

    final AuthConfig config = await client.getConfig();

    if (!await client.ensureCsrf()) {
      return AuthResult.failed(L10().csrfTokenMissing);
    }

    final AuthResult result = await method.authenticate(client, config);

    return _handleResult(result);
  }

  /*
   * Submit a code (TOTP or recovery code) for a pending MFA flow.
   * If the server then asks whether to trust this device, answer with [trustDevice]
   */
  Future<AuthResult> submitMfaCode(
    String code, {
    bool trustDevice = false,
  }) async {
    AuthResult result = await client.authenticateMfa(code);

    if (result.pendingFlow?.id == FLOW_MFA_TRUST) {
      result = await client.trustDevice(trustDevice);
    }

    return _handleResult(result);
  }

  Future<AuthResult> _handleResult(AuthResult result) async {
    debug("InvenTreeAuth: ${result}");

    switch (result.status) {
      case AuthStatus.authenticated:
        if (!await _completeLogin()) {
          return AuthResult.failed(L10().sessionSaveFailed);
        }
      case AuthStatus.flowPending:
        break;
      case AuthStatus.failed:
        // The server already has an authenticated session for these cookies
        if (result.statusCode == 409) {
          InvenTreeAPI().session.clearAuthCookies();
          return AuthResult.failed(L10().authSessionConflict, statusCode: 409);
        }
    }

    return result;
  }

  /*
   * Login completed - persist the session cookies against the profile.
   *
   * Returns false if the session could not be saved. In that case the login is
   * treated as failed: the new session is ended on the server and discarded,
   * rather than leaving the user apparently logged in without a stored session.
   */
  Future<bool> _completeLogin() async {
    final UserProfile? profile = _profile;

    if (profile == null) {
      return true;
    }

    final InvenTreeAPI api = InvenTreeAPI();

    if (!await UserProfileDBManager().saveSession(profile, api.session)) {
      debug(
        "InvenTreeAuth: Login succeeded, but the session could not be saved",
      );

      await client.logout();
      api.session.clearAuthCookies();

      profile.hasSession = false;
      _profile = null;
      _username = "";

      return false;
    }

    profile.hasSession = api.session.hasSession;

    if (_username.isNotEmpty && _username != profile.username) {
      profile.username = _username;
      await UserProfileDBManager().updateProfile(profile);
    }

    _profile = null;
    _username = "";

    return true;
  }

  /*
   * Logout the provided profile.
   * If the profile is currently connected, the server session is also ended.
   *
   * Returns false if the stored session could not be removed from the device -
   * the profile may still be logged in, and the user must be told.
   */
  Future<bool> logout(UserProfile profile) async {
    final InvenTreeAPI api = InvenTreeAPI();

    final bool active = api.profile?.key == profile.key;

    if (active && api.session.hasSession) {
      await client.logout();
    }

    // Remove the session, but keep any other cookies (e.g. the MFA "trusted device"
    // cookie) - as a browser does on logout
    final SessionStore session = active
        ? api.session
        : await UserProfileDBManager().loadSession(profile);

    final bool removed = await UserProfileDBManager().removeStoredSession(
      profile,
      session,
    );

    if (!removed) {
      debug("InvenTreeAuth: Logout - stored session could not be removed");
    }

    profile.hasSession = !removed;

    if (active) {
      api.disconnectFromServer();
    }

    return removed;
  }
}
