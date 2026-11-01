import "package:inventree/api.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/helpers.dart";

/*
 * Thin wrapper around the allauth "headless" API endpoints exposed by the server.
 * InvenTree only exposes the "browser" client, which uses session + CSRF cookies.
 *
 * All requests are made via InvenTreeAPI, which attaches (and captures)
 * the session cookies for the active profile.
 */
class AllauthClient {
  const AllauthClient();

  static const String URL_CONFIG = "auth/v1/config";
  static const String URL_SESSION = "auth/v1/auth/session";
  static const String URL_LOGIN = "auth/v1/auth/login";
  static const String URL_MFA_AUTHENTICATE = "auth/v1/auth/2fa/authenticate";
  static const String URL_MFA_TRUST = "auth/v1/auth/2fa/trust";
  static const String URL_PROVIDER_TOKEN = "auth/v1/auth/provider/token";

  InvenTreeAPI get _api => InvenTreeAPI();

  // Server authentication configuration
  Future<AuthConfig> getConfig() async {
    final response = await _api.get(URL_CONFIG, expectedStatusCode: null);

    return AuthConfig.fromResponse(response);
  }

  // Current session status
  Future<AuthResult> getSession() async {
    final response = await _api.get(URL_SESSION, expectedStatusCode: null);

    return AuthResult.fromResponse(response);
  }

  /*
   * Ensure that we have a CSRF token before making any "unsafe" requests.
   * Requesting the session status causes the server to issue a CSRF cookie.
   */
  Future<bool> ensureCsrf() async {
    if (_api.session.hasCsrfToken) {
      return true;
    }

    await _api.get(URL_SESSION, expectedStatusCode: null);

    if (!_api.session.hasCsrfToken) {
      debug("AllauthClient: Server did not provide a CSRF token");
      return false;
    }

    return true;
  }

  Future<AuthResult> _post(String url, Map<String, dynamic> body) async {
    final response = await _api.post(url, body: body, expectedStatusCode: null);

    return AuthResult.fromResponse(response);
  }

  // Login with username (or email) and password
  Future<AuthResult> loginPassword({
    required String login,
    required String password,
    String field = "username",
  }) async {
    return _post(URL_LOGIN, {field: login, "password": password});
  }

  // Provide a TOTP (or recovery) code to complete a pending MFA flow
  Future<AuthResult> authenticateMfa(String code) async {
    return _post(URL_MFA_AUTHENTICATE, {"code": code});
  }

  // Respond to a pending "trust this device" flow
  Future<AuthResult> trustDevice(bool trust) async {
    return _post(URL_MFA_TRUST, {"trust": trust});
  }

  /*
   * Login with a token issued by a third-party (SSO) provider.
   * Not yet used by the app - provided for future SSO support.
   */
  Future<AuthResult> loginProviderToken({
    required String provider,
    required Map<String, dynamic> token,
    String process = "login",
  }) async {
    return _post(URL_PROVIDER_TOKEN, {
      "provider": provider,
      "process": process,
      "token": token,
    });
  }

  // End the server session (the server responds with 401 on success)
  Future<void> logout() async {
    await _api.delete(URL_SESSION);
  }
}
