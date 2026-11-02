/*
 * Login flow tests against a running InvenTree server.
 *
 * Requires a server (with the demo dataset) at INVENTREE_TEST_SERVER,
 * and an MFA (TOTP) enabled account. Credentials can be overridden with
 * environment variables - see the constants below.
 *
 * Note: the server rate-limits failed logins (5 per minute per account),
 * so avoid re-running this file in quick succession.
 */

import "dart:io";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/auth/allauth_client.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/auth/session_store.dart";
import "package:inventree/user_profile.dart";

import "setup.dart";

String _env(String name, String fallback) =>
    Platform.environment[name] ?? fallback;

final String authServer = _env(
  "INVENTREE_TEST_SERVER",
  "http://127.0.0.1:8000/",
);

final String basicUsername = _env("INVENTREE_TEST_USERNAME", "allaccess");
final String basicPassword = _env("INVENTREE_TEST_PASSWORD", "nolimits");

final String mfaUsername = _env("INVENTREE_TEST_MFA_USERNAME", "mfauser");
final String mfaPassword = _env(
  "INVENTREE_TEST_MFA_PASSWORD",
  "mfauserpassword",
);
final String mfaSecret = _env(
  "INVENTREE_TEST_MFA_SECRET",
  "TFFPZIB4VAOKMNMYWIYVMPGBE24RZIHF",
);

const String basicProfileName = "Auth Test - Basic";
const String mfaProfileName = "Auth Test - MFA";

/*
 * TOTP (RFC 6238) code generation - SHA1, 6 digits, 30 second period
 */
const int _totpPeriod = 30;

Uint8List _base32Decode(String input) {
  const String alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

  final List<int> bytes = [];
  int buffer = 0;
  int bits = 0;

  for (final String c in input.toUpperCase().replaceAll("=", "").split("")) {
    final int value = alphabet.indexOf(c);

    if (value < 0) {
      throw FormatException("Invalid base32 character: ${c}");
    }

    buffer = (buffer << 5) | value;
    bits += 5;

    if (bits >= 8) {
      bits -= 8;
      bytes.add((buffer >> bits) & 0xff);
    }
  }

  return Uint8List.fromList(bytes);
}

int _totpWindow([DateTime? time]) =>
    (time ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000 ~/ _totpPeriod;

String totpCode(String secret, int window) {
  final counter = ByteData(8)..setInt64(0, window);

  final List<int> hash = Hmac(
    sha1,
    _base32Decode(secret),
  ).convert(counter.buffer.asUint8List()).bytes;

  final int offset = hash.last & 0x0f;

  final int value =
      ((hash[offset] & 0x7f) << 24) |
      (hash[offset + 1] << 16) |
      (hash[offset + 2] << 8) |
      hash[offset + 3];

  return (value % 1000000).toString().padLeft(6, "0");
}

// Most recent TOTP window used in this test run
int _lastWindow = -1;

/*
 * Return a TOTP code which has not been used yet in this run.
 * The server rejects re-use of a code, so wait for the next window if required
 * (or if the current window is about to expire)
 */
Future<String> freshTotpCode() async {
  while (true) {
    final DateTime now = DateTime.now();
    final int window = _totpWindow(now);
    final int remaining =
        _totpPeriod - (now.millisecondsSinceEpoch ~/ 1000) % _totpPeriod;

    if (window > _lastWindow && remaining > 3) {
      _lastWindow = window;
      return totpCode(mfaSecret, window);
    }

    await Future<void>.delayed(Duration(seconds: remaining, milliseconds: 200));
  }
}

/*
 * Submit a valid TOTP code for the pending MFA flow.
 * A code may have been used by a previous test run (within the same window),
 * in which case it is rejected - so retry once with the next code.
 */
Future<AuthResult> submitValidMfaCode({bool trustDevice = false}) async {
  AuthResult result = await InvenTreeAuth().submitMfaCode(
    await freshTotpCode(),
    trustDevice: trustDevice,
  );

  if (result.status == AuthStatus.failed && result.statusCode == 400) {
    result = await InvenTreeAuth().submitMfaCode(
      await freshTotpCode(),
      trustDevice: trustDevice,
    );
  }

  return result;
}

/*
 * Create (or reset) a profile pointing at the test server
 */
Future<UserProfile> authProfile(String name) async {
  final manager = UserProfileDBManager();

  UserProfile? profile = await manager.getProfileByName(name);

  if (profile != null) {
    await manager.deleteProfile(profile);
  }

  expect(
    await manager.addProfile(UserProfile(name: name, server: authServer)),
    equals(true),
  );

  profile = await manager.getProfileByName(name);
  expect(profile, isNotNull);

  return profile!;
}

/*
 * Request the current user with only the provided session cookie
 * (independent of the app's API client) and return the status code
 */
Future<int> userStatusWithSession(String sessionId) async {
  final client = HttpClient();

  try {
    final request = await client.getUrl(
      Uri.parse(authServer).resolve("api/user/me/"),
    );
    request.headers.set(HttpHeaders.acceptHeader, "application/json");
    request.headers.set(
      HttpHeaders.cookieHeader,
      "${SESSION_COOKIE_NAME}=${sessionId}",
    );

    final response = await request.close();
    await response.drain<void>();

    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

/*
 * End the provided session on the server, independent of the app's API client
 * (e.g. as if the session was ended from another device, or the web interface)
 */
Future<void> endSessionExternally(SessionStore session) async {
  final Uri server = Uri.parse(authServer);
  final Uri url = server.resolve("api/auth/v1/auth/session");
  final client = HttpClient();

  try {
    final request = await client.deleteUrl(url);
    request.headers.set(HttpHeaders.acceptHeader, "application/json");
    request.headers.set(HttpHeaders.cookieHeader, session.cookieHeader(url));
    request.headers.set("X-CSRFToken", session.csrfToken);
    request.headers.set("Origin", server.origin);
    request.headers.set(HttpHeaders.refererHeader, authServer);

    final response = await request.close();
    await response.drain<void>();

    // allauth responds with 401 once the session has ended
    expect(response.statusCode, equals(401));
  } finally {
    client.close(force: true);
  }
}

String storedSessionId(SessionStore session) {
  final RegExp pattern = RegExp("${SESSION_COOKIE_NAME}=([^;]+)");

  return pattern
          .firstMatch(session.cookieHeader(Uri.parse(authServer)))
          ?.group(1) ??
      "";
}

void main() {
  setupTestEnv();

  test("TOTP code generation (RFC 6238 test vector)", () {
    // RFC 6238 Appendix B - SHA1, T = 59s, secret "12345678901234567890"
    const String rfcSecret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";

    expect(totpCode(rfcSecret, 59 ~/ 30), equals("287082"));
    expect(totpCode(rfcSecret, 1111111109 ~/ 30), equals("081804"));
  });

  tearDownAll(() async {
    InvenTreeAPI().disconnectFromServer();

    for (final name in [basicProfileName, mfaProfileName]) {
      final profile = await UserProfileDBManager().getProfileByName(name);

      if (profile != null) {
        await UserProfileDBManager().deleteProfile(profile);
      }
    }
  });

  group("Server config:", () {
    test("Auth configuration", () async {
      final UserProfile profile = await authProfile(basicProfileName);

      await InvenTreeAPI().beginAuthentication(profile);

      expect(await InvenTreeAPI().checkServer(), equals(true));

      final AuthConfig config = await const AllauthClient().getConfig();

      expect(config.loginField, equals("username"));
      expect(config.mfaTypes, contains(MFA_TYPE_TOTP));
    });
  });

  group("Basic auth:", () {
    late UserProfile profile;

    setUpAll(() async {
      profile = await authProfile(basicProfileName);
    });

    test("Invalid password", () async {
      final AuthResult result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(basicUsername, "${basicPassword}-wrong"),
      );

      expect(result.status, equals(AuthStatus.failed));
      expect(result.statusCode, equals(400));
      expect(result.errorMessage, isNotEmpty);

      expect(profile.hasSession, equals(false));
      expect(
        (await UserProfileDBManager().loadSession(profile)).hasSession,
        equals(false),
      );

      // A failed login does not remember the username
      expect(profile.username, isEmpty);
    });

    test("Login", () async {
      final AuthResult result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(basicUsername, basicPassword),
      );

      expect(result.status, equals(AuthStatus.authenticated));
      expect(profile.hasSession, equals(true));

      // Session and CSRF cookies are persisted to secure storage
      final SessionStore stored = await UserProfileDBManager().loadSession(
        profile,
      );
      expect(stored.hasSession, equals(true));
      expect(stored.hasCsrfToken, equals(true));

      // Username is remembered against the profile
      final UserProfile? saved = await UserProfileDBManager().getProfileByName(
        basicProfileName,
      );
      expect(saved!.username, equals(basicUsername));
    });

    test("Connect with stored session", () async {
      final api = InvenTreeAPI();

      // Start from a clean API state - the session is loaded from storage
      api.disconnectFromServer();

      expect(await api.connectToServer(profile), equals(true));
      expect(api.isConnected(), equals(true));
      expect(api.username, equals(basicUsername));

      // No API token is ever used
      final headers = api.defaultHeaders(method: "POST");
      expect(
        headers.containsKey(HttpHeaders.authorizationHeader),
        equals(false),
      );
      expect(headers["X-CSRFToken"], isNotEmpty);
    });

    test("Logout", () async {
      final api = InvenTreeAPI();

      expect(await api.connectToServer(profile), equals(true));

      final String sessionId = storedSessionId(api.session);
      expect(sessionId, isNotEmpty);
      expect(await userStatusWithSession(sessionId), equals(200));

      // Copy of the full cookie jar (session + CSRF) from before logout
      final String sessionCopy = api.session.toJson();

      await InvenTreeAuth().logout(profile);

      expect(api.isConnected(), equals(false));
      expect(profile.hasSession, equals(false));
      expect(
        (await UserProfileDBManager().loadSession(profile)).hasSession,
        equals(false),
      );

      // The session has been ended on the server
      expect(await userStatusWithSession(sessionId), isIn([401, 403]));

      // Restoring the old session must not log the user back in
      await UserProfileDBManager().saveSession(
        profile,
        SessionStore.fromJson(authServer, sessionCopy),
      );
      expect(
        (await UserProfileDBManager().loadSession(profile)).hasSession,
        equals(true),
      );

      expect(await api.connectToServer(profile), equals(false));
      expect(api.isConnected(), equals(false));

      // ... and the rejected session is discarded
      expect(
        (await UserProfileDBManager().loadSession(profile)).hasSession,
        equals(false),
      );

      // Username is retained after logout
      final UserProfile? saved = await UserProfileDBManager().getProfileByName(
        basicProfileName,
      );
      expect(saved!.username, equals(basicUsername));
    });

    test("Invalid stored session", () async {
      // A session cookie which the server does not recognise
      final session = SessionStore(server: authServer);
      session.captureHeaders(Uri.parse(authServer).resolve("api/"), [
        "${SESSION_COOKIE_NAME}=not-a-valid-session; Path=/",
      ]);
      await UserProfileDBManager().saveSession(profile, session);

      expect(await InvenTreeAPI().connectToServer(profile), equals(false));

      // The invalid session is discarded
      expect(
        (await UserProfileDBManager().loadSession(profile)).hasSession,
        equals(false),
      );
    });

    test("Session expires while connected", () async {
      final api = InvenTreeAPI();

      final AuthResult result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(basicUsername, basicPassword),
      );
      expect(result.status, equals(AuthStatus.authenticated));

      expect(await api.connectToServer(profile), equals(true));

      // Requests succeed while the session is valid
      expect((await api.get("part/", params: {"limit": "1"})).statusCode, 200);

      // The session is ended elsewhere
      await endSessionExternally(api.session);

      // The next request detects the expired session
      final response = await api.get("part/", params: {"limit": "1"});
      expect(response.statusCode, equals(401));

      expect(api.isConnected(), equals(false));
      expect(profile.hasSession, equals(false));
      expect(
        (await UserProfileDBManager().loadSession(profile)).hasSession,
        equals(false),
      );

      // Username is retained, ready to login again
      final UserProfile? saved = await UserProfileDBManager().getProfileByName(
        basicProfileName,
      );
      expect(saved!.username, equals(basicUsername));

      // ... and logging in again restores the connection
      expect(
        (await InvenTreeAuth().beginLogin(
          profile,
          PasswordAuthMethod(basicUsername, basicPassword),
        )).authenticated,
        equals(true),
      );
      expect(await api.connectToServer(profile), equals(true));

      await InvenTreeAuth().logout(profile);
    });
  });

  group("MFA:", () {
    late UserProfile profile;

    setUpAll(() async {
      profile = await authProfile(mfaProfileName);
    });

    test("Password login requires MFA", () async {
      final AuthResult result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(mfaUsername, mfaPassword),
      );

      expect(result.status, equals(AuthStatus.flowPending));
      expect(result.pendingFlow!.id, equals(FLOW_MFA_AUTHENTICATE));
      expect(result.pendingFlow!.isSupportedMfa, equals(true));
      expect(result.pendingFlow!.types, contains(MFA_TYPE_TOTP));

      // Nothing is persisted until the login is complete
      expect(profile.hasSession, equals(false));
      expect(
        (await UserProfileDBManager().loadSession(profile)).hasSession,
        equals(false),
      );
    });

    test("Invalid code, then valid code", () async {
      AuthResult result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(mfaUsername, mfaPassword),
      );
      expect(result.status, equals(AuthStatus.flowPending));

      // A code which is (almost certainly) not valid for the current window
      final String current = totpCode(mfaSecret, _totpWindow());
      final String invalid = ((int.parse(current) + 1) % 1000000)
          .toString()
          .padLeft(6, "0");

      result = await InvenTreeAuth().submitMfaCode(invalid);

      expect(result.status, equals(AuthStatus.failed));
      expect(result.statusCode, equals(400));
      expect(result.errorMessage, isNotEmpty);
      expect(profile.hasSession, equals(false));

      // The pending login can be completed with a valid code
      result = await submitValidMfaCode();

      expect(result.status, equals(AuthStatus.authenticated));
      expect(profile.hasSession, equals(true));

      expect(await InvenTreeAPI().connectToServer(profile), equals(true));
      expect(InvenTreeAPI().username, equals(mfaUsername));

      await InvenTreeAuth().logout(profile);
      expect(profile.hasSession, equals(false));
    }, timeout: Timeout(Duration(minutes: 2)));

    test("Trusted device skips MFA", () async {
      AuthResult result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(mfaUsername, mfaPassword),
      );
      expect(result.status, equals(AuthStatus.flowPending));

      result = await submitValidMfaCode(trustDevice: true);
      expect(result.status, equals(AuthStatus.authenticated));

      SessionStore stored = await UserProfileDBManager().loadSession(profile);
      expect(stored.cookieNames, contains("mfa_trusted"));

      expect(await InvenTreeAPI().connectToServer(profile), equals(true));
      await InvenTreeAuth().logout(profile);

      // The trusted device cookie survives logout
      stored = await UserProfileDBManager().loadSession(profile);
      expect(stored.hasSession, equals(false));
      expect(stored.cookieNames, contains("mfa_trusted"));

      // ... so the next login does not require MFA
      result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(mfaUsername, mfaPassword),
      );
      expect(result.status, equals(AuthStatus.authenticated));

      expect(await InvenTreeAPI().connectToServer(profile), equals(true));
      await InvenTreeAuth().logout(profile);

      // Without the trusted device cookie, MFA is required again
      await UserProfileDBManager().clearSession(profile);

      result = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod(mfaUsername, mfaPassword),
      );
      expect(result.status, equals(AuthStatus.flowPending));
      expect(result.pendingFlow!.id, equals(FLOW_MFA_AUTHENTICATE));
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}
