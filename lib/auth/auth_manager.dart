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
        await _completeLogin();
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

  // Login completed - persist the session cookies against the profile
  Future<void> _completeLogin() async {
    final UserProfile? profile = _profile;

    if (profile == null) {
      return;
    }

    await UserProfileDBManager().saveSession(profile, InvenTreeAPI().session);

    profile.hasSession = InvenTreeAPI().session.hasSession;

    if (_username.isNotEmpty && _username != profile.username) {
      profile.username = _username;
      await UserProfileDBManager().updateProfile(profile);
    }

    _profile = null;
    _username = "";
  }

  /*
   * Logout the provided profile.
   * If the profile is currently connected, the server session is also ended.
   */
  Future<void> logout(UserProfile profile) async {
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

    session.clearAuthCookies();

    await UserProfileDBManager().saveSession(profile, session);

    profile.hasSession = false;

    if (active) {
      api.disconnectFromServer();
    }
  }
}
