/*
 * Authentication flow tests against an in-process fake server (see fake_server.dart).
 *
 * These cover error paths and edge cases which are difficult (or impossible)
 * to reproduce against a real InvenTree server. No running server is required.
 */

import "dart:async";
import "dart:io";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/auth/session_store.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/managed_config.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/widget/dialogs.dart";

import "fake_server.dart";
import "setup.dart";

const String profileName = "Auth Flow Test";

late FakeInvenTreeServer server;

// Profiles created by the current test (removed in tearDown)
final List<String> _profiles = [];

InvenTreeAPI get api => InvenTreeAPI();

UserProfileDBManager get manager => UserProfileDBManager();

/*
 * Create a new profile pointing at the provided fake server
 */
Future<UserProfile> fakeProfile(
  FakeInvenTreeServer fake, {
  String name = profileName,
}) async {
  final UserProfile? existing = await manager.getProfileByName(name);

  if (existing != null) {
    await manager.deleteProfile(existing);
  }

  expect(
    await manager.addProfile(UserProfile(name: name, server: fake.url)),
    equals(true),
  );

  _profiles.add(name);

  return (await manager.getProfileByName(name))!;
}

Future<AuthResult> login(
  UserProfile profile, {
  String username = "user",
  String password = "password",
}) =>
    InvenTreeAuth().beginLogin(profile, PasswordAuthMethod(username, password));

/*
 * Login and connect, then wait for background requests (status codes) to finish
 */
Future<void> loginAndConnect(UserProfile profile) async {
  expect((await login(profile)).authenticated, equals(true));
  expect(await api.connectToServer(profile), equals(true));

  await Future<void>.delayed(Duration(milliseconds: 200));
}

Future<SessionStore> stored(UserProfile profile) =>
    manager.loadSession(profile);

// Wait for an asynchronous condition (e.g. a session being persisted)
Future<void> eventually(Future<bool> Function() check) async {
  for (int i = 0; i < 50; i++) {
    if (await check()) return;
    await Future<void>.delayed(Duration(milliseconds: 20));
  }

  fail("Condition not met");
}

bool logged(String msg) => debugContains(msg, raiseAssert: false);

/*
 * Run [body], returning everything printed (including by asynchronous
 * work started within it, e.g. error reports)
 */
Future<List<String>> capturePrints(Future<void> Function() body) async {
  final List<String> printed = [];

  await runZoned(
    () async {
      await body();

      // Allow error reports (not awaited by the API) to complete
      await Future<void>.delayed(Duration(milliseconds: 200));
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        printed.add(line);
        parent.print(zone, line);
      },
    ),
  );

  return printed;
}

FakeResponse unauthorized(FakeRequest _) => FakeResponse(
  401,
  body: {"detail": "Authentication credentials were not provided."},
);

void main() {
  setupTestEnv();

  setUp(() async {
    clearDebugMessage();
    server = await FakeInvenTreeServer.start();
  });

  tearDown(() async {
    secureStorageFailures.clear();

    api.disconnectFromServer();

    for (final name in _profiles) {
      final profile = await manager.getProfileByName(name);

      if (profile != null) {
        await manager.deleteProfile(profile);
      }
    }

    _profiles.clear();

    await server.close();
  });

  group("Login:", () {
    test("Password login", () async {
      final profile = await fakeProfile(server);

      final AuthResult result = await login(profile);
      expect(result.authenticated, equals(true));

      // CSRF token was requested before the login POST
      final List<String> sequence = server.requests
          .map((r) => r.toString())
          .toList();
      expect(
        sequence.indexOf("GET /api/auth/v1/auth/session"),
        lessThan(sequence.indexOf("POST /api/auth/v1/auth/login")),
      );

      expect((await stored(profile)).hasSession, equals(true));
      expect(profile.username, equals("user"));
    });

    test("Email-only login sends the email field", () async {
      server.loginMethods = ["email"];
      server.users["user@example.com"] = "password";

      final profile = await fakeProfile(server);

      final AuthResult result = await login(
        profile,
        username: "user@example.com",
      );
      expect(result.authenticated, equals(true));

      final Map<String, dynamic> body = server
          .received("POST", "api/auth/v1/auth/login")
          .single
          .json;
      expect(body["email"], equals("user@example.com"));
      expect(body.containsKey("username"), equals(false));
    });

    test("MFA code", () async {
      final profile = await fakeProfile(server);

      AuthResult result = await login(profile, username: "mfa");
      expect(result.status, equals(AuthStatus.flowPending));
      expect(result.pendingFlow!.id, equals(FLOW_MFA_AUTHENTICATE));
      expect((await stored(profile)).hasSession, equals(false));

      result = await InvenTreeAuth().submitMfaCode("000000");
      expect(result.status, equals(AuthStatus.failed));
      expect(result.errorMessage, equals("Incorrect code."));

      result = await InvenTreeAuth().submitMfaCode(server.validCode);
      expect(result.authenticated, equals(true));
      expect((await stored(profile)).hasSession, equals(true));
    });

    test("Session conflict (409)", () async {
      final profile = await fakeProfile(server);

      server.once(
        "POST",
        "api/auth/v1/auth/login",
        (_) => FakeResponse(409, body: {"status": 409}),
      );

      final AuthResult result = await login(profile);

      expect(result.status, equals(AuthStatus.failed));
      expect(result.statusCode, equals(409));
      expect(result.errorMessage, equals(L10().authSessionConflict));

      // Auth cookies are discarded, so the next attempt starts afresh
      expect(api.session.hasSession, equals(false));
      expect(api.session.hasCsrfToken, equals(false));

      expect((await login(profile)).authenticated, equals(true));
    });

    test("Server does not provide a CSRF token", () async {
      final profile = await fakeProfile(server);

      server.always(
        "GET",
        "api/auth/v1/auth/session",
        (_) => FakeResponse(401, body: {"status": 401}),
      );

      final AuthResult result = await login(profile);

      expect(result.status, equals(AuthStatus.failed));
      expect(result.errorMessage, equals(L10().csrfTokenMissing));

      // Credentials are never sent without CSRF protection
      expect(server.received("POST", "api/auth/v1/auth/login"), isEmpty);
    });

    test("Too many failed login attempts", () async {
      final profile = await fakeProfile(server);

      // Failed-login rate limit - reported by allauth as a form error
      server.once(
        "POST",
        "api/auth/v1/auth/login",
        (_) => FakeResponse(
          400,
          body: {
            "status": 400,
            "errors": [
              {
                "message": "Too many failed login attempts. Try again later.",
                "code": "too_many_login_attempts",
              },
            ],
          },
        ),
      );

      AuthResult result = await login(profile);
      expect(result.statusCode, equals(400));
      expect(
        result.errorMessage,
        equals("Too many failed login attempts. Try again later."),
      );

      // Generic rate limit - no error message, so the UI falls back to the status code
      server.once(
        "POST",
        "api/auth/v1/auth/login",
        (_) => FakeResponse(429, body: {"status": 429}),
      );

      result = await login(profile);
      expect(result.status, equals(AuthStatus.failed));
      expect(result.statusCode, equals(429));
      expect(result.errorMessage, isEmpty);
      expect(statusCodeToString(429), equals(L10().response429));
    });

    test("Server API version too old", () async {
      final FakeInvenTreeServer old = await FakeInvenTreeServer.start(
        apiVersion: 300,
      );

      try {
        final profile = await fakeProfile(old);

        final AuthResult result = await login(profile);

        expect(result.status, equals(AuthStatus.failed));
        expect(logged("showServerError: '${L10().serverOld}'"), equals(true));

        // No authentication is attempted
        expect(old.received("GET", "api/auth/v1/config"), isEmpty);
        expect(old.received("POST", "api/auth/v1/auth/login"), isEmpty);
      } finally {
        await old.close();
      }
    });
  });

  group("Connect:", () {
    test("Expired session shows message and login screen", () async {
      final profile = await fakeProfile(server);

      // A session the server does not know about
      final session = SessionStore(server: server.url);
      session.captureHeaders(Uri.parse(server.url), [
        "sessionid=stale; Path=/",
      ]);
      await manager.saveSession(profile, session);

      expect(await api.connectToServer(profile), equals(false));

      expect((await stored(profile)).hasSession, equals(false));
      expect(
        logged("showServerError: '${L10().sessionExpired}'"),
        equals(true),
      );
      expect(logged("Opening login screen for '${profileName}'"), equals(true));
    });

    test("MFA registration required", () async {
      final profile = await fakeProfile(server);

      expect((await login(profile)).authenticated, equals(true));

      // Server enforces MFA, which this user has not configured
      server.always(
        "GET",
        "api/user/me/",
        (_) => FakeResponse(
          401,
          body: {
            "id": "mfa_register",
            "error": "You must enable two-factor authentication",
          },
        ),
      );

      expect(await api.connectToServer(profile), equals(false));

      // The restricted server session is ended, and discarded locally
      expect(server.received("DELETE", "api/auth/v1/auth/session").length, 1);
      expect(server.sessions, isEmpty);
      expect((await stored(profile)).hasSession, equals(false));

      expect(
        logged("showServerError: '${L10().mfaRegistrationRequired}'"),
        equals(true),
      );

      // Login would not help - so the login screen is not opened
      expect(logged("Opening login screen"), equals(false));
    });

    final Map<String, FakeResponse> failures = {
      "Service unavailable (503)": FakeResponse(503),
      "Connection dropped": FakeResponse.drop(),
    };

    for (final failure in failures.entries) {
      test("${failure.key} keeps the session", () async {
        final profile = await fakeProfile(server);

        expect((await login(profile)).authenticated, equals(true));

        server.once("GET", "api/user/me/", (_) => failure.value);

        expect(await api.connectToServer(profile), equals(false));

        // Session retained - and still valid once the server recovers
        expect(profile.hasSession, equals(true));
        expect((await stored(profile)).hasSession, equals(true));
        expect(logged("Opening login screen"), equals(false));

        expect(await api.connectToServer(profile), equals(true));
      });
    }
  });

  group("While connected:", () {
    late UserProfile profile;

    setUp(() async {
      profile = await fakeProfile(server);
      await loginAndConnect(profile);
      clearDebugMessage();
    });

    int userChecks() => server.received("GET", "api/user/me/").length;

    test("Session expiry opens the login screen", () async {
      server.endAllSessions();

      final response = await api.get("part/", expectedStatusCode: null);
      expect(response.statusCode, equals(401));

      expect(api.isConnected(), equals(false));
      expect((await stored(profile)).hasSession, equals(false));
      expect(profile.username, equals("user"));

      expect(
        logged("showServerError: '${L10().sessionExpired}'"),
        equals(true),
      );
      expect(logged("Opening login screen for '${profileName}'"), equals(true));
    });

    int loginPrompts() =>
        debug_messages.where((m) => m.contains("Opening login screen")).length;

    // Errors displayed to the user, other than the "session expired" message
    List<String> displayedErrors() => debug_messages
        .where(
          (m) =>
              m.startsWith("showServerError: '") &&
              !m.contains(L10().sessionExpired),
        )
        .toList();

    test("Model requests redirect to login without errors", () async {
      server.endAllSessions();

      // As made by list views (paginator) and detail views
      await Future.wait([
        InvenTreePart().listPaginated(10, 0),
        InvenTreePart().get(1),
        InvenTreeStockItem().listPaginated(10, 0),
      ]);

      expect(api.isConnected(), equals(false));
      expect(displayedErrors(), isEmpty);
      expect(loginPrompts(), equals(1));

      // Errors were suppressed (not just missing)
      expect(logged("showServerError: suppressed"), equals(true));
    });

    test("Requests after expiry redirect to login without errors", () async {
      server.endAllSessions();

      await InvenTreePart().listPaginated(10, 0);
      expect(api.isConnected(), equals(false));
      expect(loginPrompts(), equals(1));

      // Screens which are still open continue to make requests
      await InvenTreePart().get(1);
      await api.post("part/", body: {"name": "A"});

      final File file = File(
        "${Directory.systemTemp.path}/inventree-auth-upload.txt",
      )..writeAsStringSync("test");

      try {
        await api.uploadFile("part/attachment/", file);
      } finally {
        file.deleteSync();
      }

      expect(displayedErrors(), isEmpty);

      // The login screen is already open - it is not opened again
      expect(loginPrompts(), equals(1));
    });

    test("Login screen dismissed - next request opens it again", () async {
      server.endAllSessions();

      await InvenTreePart().listPaginated(10, 0);
      expect(loginPrompts(), equals(1));

      // User leaves the login screen without logging in
      api.onLoginScreenClosed();
      expect(api.suppressServerErrors, equals(false));

      // ... and continues to use a screen which is still open
      await InvenTreePart().listPaginated(10, 0);

      expect(loginPrompts(), equals(2));
      expect(displayedErrors(), isEmpty);
    });

    test("Rejected requests are marked as handled", () async {
      server.endAllSessions();

      final response = await api.get("part/");

      expect(response.statusCode, equals(401));
      expect(response.errorDetail, isNotEmpty);
    });

    test("Download with an expired session", () async {
      server.endAllSessions();

      await api.downloadFile(
        "${server.url}media/inventree-auth-expired.txt",
        openOnDownload: false,
      );

      expect(api.isConnected(), equals(false));
      expect(displayedErrors(), isEmpty);
      expect(loginPrompts(), equals(1));
    });

    test("Errors are displayed again after login", () async {
      server.endAllSessions();
      await api.get("part/");
      expect(api.isConnected(), equals(false));

      await loginAndConnect(profile);
      clearDebugMessage();

      // An unrelated error is displayed as normal
      server.once(
        "GET",
        "api/part/",
        (_) => FakeResponse(400, body: {"detail": "Bad request"}),
      );
      await InvenTreePart().listPaginated(10, 0);

      expect(displayedErrors(), isNotEmpty);
      expect(loginPrompts(), equals(0));
    });

    /*
     * Start a request which is rejected (triggering a session check), and hold
     * the session check response until [release] completes. A second request
     * is then rejected while the check is still running (overlapping).
     *
     * Returns the overlapping request's response.
     */
    Future<(APIResponse, APIResponse)> overlapping({
      required Completer<void> release,
      required FutureOr<FakeResponse> Function() checkResponse,
    }) async {
      final int checks = userChecks();

      server.once("GET", "api/part/", unauthorized);
      server.once("PATCH", "api/part/1/", unauthorized);

      server.once("GET", "api/user/me/", (_) async {
        await release.future;
        return checkResponse();
      });

      // First request - starts the session check
      final Future<APIResponse> first = api.get("part/");
      await eventually(() async => userChecks() == checks + 1);

      // Second request - rejected while the check is running.
      // (PATCH reports an unexpected status code itself, unlike GET)
      final Future<APIResponse> second = api.patch(
        "part/1/",
        body: {"name": "A"},
        expectedStatusCode: 200,
      );
      await eventually(
        () async => server.received("PATCH", "api/part/1/").isNotEmpty,
      );

      // Allow the second response to be processed, then complete the check
      await Future<void>.delayed(Duration(milliseconds: 50));
      release.complete();

      return (await first, await second);
    }

    test("Overlapping 401 - session valid", () async {
      final (_, second) = await overlapping(
        release: Completer<void>(),
        checkResponse: () =>
            FakeResponse(200, body: {"pk": 1, "username": "user"}),
      );

      // The session is valid, so the overlapping request is a real error
      expect(second.statusCode, equals(401));
      expect(second.errorDetail, isEmpty);
      expect(api.isConnected(), equals(true));
      expect(api.suppressServerErrors, equals(false));

      // ... and is reported as such
      expect(logged("showServerError: '${L10().response401}'"), equals(true));
      expect(logged("showServerError: suppressed"), equals(false));
      expect(loginPrompts(), equals(0));
    });

    test("Overlapping 401 - session check fails (transient)", () async {
      final (_, second) = await overlapping(
        release: Completer<void>(),
        checkResponse: () => FakeResponse(503),
      );

      // Unable to determine the session state - the session is retained,
      // and the overlapping request's error is not hidden
      expect(second.errorDetail, isEmpty);
      expect(api.isConnected(), equals(true));
      expect((await stored(profile)).hasSession, equals(true));
      expect(logged("showServerError: '${L10().response401}'"), equals(true));
      expect(loginPrompts(), equals(0));
    });

    test("Overlapping 401 - session expired", () async {
      server.endAllSessions();

      final (first, second) = await overlapping(
        release: Completer<void>(),
        checkResponse: () => unauthorized(
          FakeRequest(
            method: "GET",
            path: "/api/user/me/",
            query: {},
            rawQuery: "",
            headers: {},
            cookies: {},
            body: "",
          ),
        ),
      );

      // Both requests are handled by directing the user to login
      expect(first.errorDetail, isNotEmpty);
      expect(second.errorDetail, isNotEmpty);
      expect(api.isConnected(), equals(false));
      expect(displayedErrors(), isEmpty);
      expect(loginPrompts(), equals(1));
    });

    test("Other errors are displayed while the session is checked", () async {
      final Completer<void> release = Completer<void>();
      final int checks = userChecks();

      server.once("GET", "api/part/", unauthorized);
      server.once("GET", "api/user/me/", (_) async {
        await release.future;
        return FakeResponse(200, body: {"pk": 1, "username": "user"});
      });

      final Future<APIResponse> first = api.get("part/");
      await eventually(() async => userChecks() == checks + 1);

      // An unrelated error, while the session check is running
      server.once(
        "GET",
        "api/stock/",
        (_) => FakeResponse(400, body: {"detail": "Bad request"}),
      );
      await InvenTreeStockItem().listPaginated(10, 0);

      expect(api.suppressServerErrors, equals(false));
      expect(logged("showServerError: '${L10().response400}'"), equals(true));

      release.complete();
      await first;
    });

    test("Failed session check keeps the user identity", () async {
      expect(api.userId, equals(1));
      expect(api.username, equals("user"));

      for (final failure in [FakeResponse(503), FakeResponse.drop()]) {
        server.once("GET", "api/part/", unauthorized);
        server.once("GET", "api/user/me/", (_) => failure);

        await api.get("part/");

        // Session retained - so the identity must be too
        // (e.g. used as "checked_by" when checking a shipment)
        expect(api.isConnected(), equals(true));
        expect(api.userId, equals(1));
        expect(api.username, equals("user"));
      }
    });

    test("Successful session check refreshes the user identity", () async {
      server.once("GET", "api/part/", unauthorized);
      server.once(
        "GET",
        "api/user/me/",
        (_) => FakeResponse(200, body: {"pk": 1, "username": "renamed"}),
      );

      await api.get("part/");

      expect(api.isConnected(), equals(true));
      expect(api.username, equals("renamed"));
    });

    test("Expired session clears the user identity", () async {
      server.endAllSessions();

      await api.get("part/");

      expect(api.isConnected(), equals(false));
      expect(api.userId, equals(-1));
      expect(api.username, isEmpty);
    });

    test("Disconnect clears the user identity", () async {
      expect(api.userId, equals(1));

      api.disconnectFromServer();

      expect(api.userId, equals(-1));
      expect(api.username, isEmpty);
    });

    test("Concurrent requests check the session once", () async {
      final int before = userChecks();

      server.endAllSessions();

      await Future.wait([
        api.get("part/", expectedStatusCode: null),
        api.get("stock/", expectedStatusCode: null),
        api.get("company/", expectedStatusCode: null),
      ]);

      expect(userChecks(), equals(before + 1));
      expect(api.isConnected(), equals(false));
    });

    test("Rejected request with a valid session keeps the session", () async {
      final int before = userChecks();

      server.once("GET", "api/part/", unauthorized);

      final response = await api.get("part/", expectedStatusCode: null);
      expect(response.statusCode, equals(401));

      // Session was checked and found to be valid - so the response is not
      // treated as handled, and is reported by the caller as normal
      expect(userChecks(), equals(before + 1));
      expect(api.isConnected(), equals(true));
      expect((await stored(profile)).hasSession, equals(true));
      expect(response.errorDetail, isEmpty);
      expect(api.suppressServerErrors, equals(false));
      expect(logged("Opening login screen"), equals(false));
    });

    test("401 from an auth endpoint does not check the session", () async {
      final int before = userChecks();

      server.once(
        "GET",
        "api/auth/v1/auth/session",
        (_) => FakeResponse(401, body: {"status": 401}),
      );

      await api.get("auth/v1/auth/session", expectedStatusCode: null);

      expect(userChecks(), equals(before));
      expect(api.isConnected(), equals(true));
    });

    test("403 does not expire the session", () async {
      final int before = userChecks();

      for (final detail in [
        "You do not have permission to perform this action.",
        "CSRF Failed: CSRF token missing.",
      ]) {
        server.once(
          "GET",
          "api/part/",
          (_) => FakeResponse(403, body: {"detail": detail}),
        );

        await api.get("part/", expectedStatusCode: null);
      }

      expect(userChecks(), equals(before));
      expect(api.isConnected(), equals(true));
      expect((await stored(profile)).hasSession, equals(true));
    });

    test("MFA registration required while connected", () async {
      server.once("GET", "api/part/", unauthorized);
      server.once(
        "GET",
        "api/user/me/",
        (_) => FakeResponse(401, body: {"id": "mfa_register"}),
      );

      await api.get("part/", expectedStatusCode: null);

      expect(api.isConnected(), equals(false));
      expect(server.received("DELETE", "api/auth/v1/auth/session").length, 1);
      expect(
        logged("showServerError: '${L10().mfaRegistrationRequired}'"),
        equals(true),
      );
    });

    test("Upload with an expired session", () async {
      final File file = File(
        "${Directory.systemTemp.path}/inventree-auth-upload.txt",
      )..writeAsStringSync("test");

      try {
        server.endAllSessions();

        final response = await api.uploadFile("part/attachment/", file);
        expect(response.statusCode, equals(401));

        expect(api.isConnected(), equals(false));
        expect((await stored(profile)).hasSession, equals(false));
      } finally {
        file.deleteSync();
      }
    });
  });

  group("Requests:", () {
    late UserProfile profile;

    setUp(() async {
      profile = await fakeProfile(server);
      await loginAndConnect(profile);
    });

    test("Query parameters are URL encoded", () async {
      final Map<String, String> params = {
        "search": "M3 & M4 C++ #1?",
        "name": "a=b",
        "unicode": "Ø 10µF",
      };

      await api.get("part/", params: params);

      final FakeRequest request = server.received("GET", "api/part/").last;
      expect(request.query, equals(params));
    });

    test("Query parameters are merged with an existing query", () async {
      await api.get("part/?category=1", params: {"search": "x y"});

      final FakeRequest request = server.received("GET", "api/part/").last;
      expect(request.query, equals({"category": "1", "search": "x y"}));
    });

    test("No query string without parameters", () async {
      await api.get("part/");

      expect(server.received("GET", "api/part/").last.rawQuery, isEmpty);
    });

    test("Server error response is read and reported", () async {
      server.once(
        "GET",
        "api/part/1/",
        (_) => FakeResponse(500, body: {"detail": "Database unavailable"}),
      );

      late APIResponse response;

      final List<String> printed = await capturePrints(() async {
        response = await api.get("part/1/");
      });

      expect(response.statusCode, equals(500));
      expect(response.asMap()["detail"], equals("Database unavailable"));

      // The error is displayed, including the server's description
      expect(logged("showServerError: '${L10().response500}'"), equals(true));

      // ... and reported, including the response data
      final String report = printed.firstWhere(
        (line) =>
            line.startsWith("Sending user message to Sentry: Server error"),
      );
      expect(report, contains("Database unavailable"));
    });

    test("Server error page (not JSON) is reported once", () async {
      const String page = "<html><h1>Internal Server Error</h1></html>";

      server.once(
        "GET",
        "api/part/1/",
        (_) => FakeResponse(500, rawBody: page),
      );

      final File file = File(
        "${Directory.systemTemp.path}/inventree-auth-upload.txt",
      )..writeAsStringSync("test");

      server.once(
        "POST",
        "api/part/attachment/",
        (_) => FakeResponse(500, rawBody: page),
      );

      late APIResponse response;

      final List<String> printed = await capturePrints(() async {
        response = await api.get("part/1/");
        await api.uploadFile("part/attachment/", file);
      });

      file.deleteSync();

      expect(response.statusCode, equals(500));
      expect(response.asMap(), isEmpty);

      final List<String> reports = printed
          .where((line) => line.startsWith("Sending user message to Sentry"))
          .toList();

      expect(reports.length, equals(2));
      expect(reports[0], contains("Server error"));
      expect(reports[0], contains("Internal Server Error"));
      expect(reports[1], contains("Server error in uploadFile()"));
      expect(reports[1], contains("Internal Server Error"));
    });

    test("CSRF headers on unsafe requests", () async {
      expect((await api.post("part/", body: {"name": "A"})).statusCode, 201);
      expect(
        (await api.patch("part/1/", body: {"name": "B"})).statusCode,
        equals(200),
      );
      expect((await api.delete("part/1/")).statusCode, equals(200));

      final String origin = Uri.parse(server.url).origin;

      for (final method in ["POST", "PATCH", "DELETE"]) {
        final FakeRequest request = server.requests.lastWhere(
          (r) => r.method == method && r.path.startsWith("/api/part/"),
        );

        expect(request.cookies["sessionid"], isNotEmpty);
        expect(request.headers["x-csrftoken"], equals(api.session.csrfToken));
        expect(request.headers["origin"], equals(origin));
        expect(request.headers["referer"], startsWith(server.url));
        expect(request.headers.containsKey("authorization"), equals(false));
      }

      // Safe requests do not include CSRF headers
      await api.get("part/");

      final FakeRequest get = server.received("GET", "api/part/").last;
      expect(get.cookies["sessionid"], isNotEmpty);
      expect(get.headers.containsKey("x-csrftoken"), equals(false));
    });

    test("Upload sends credentials and captures cookies", () async {
      final File file = File(
        "${Directory.systemTemp.path}/inventree-auth-upload.txt",
      )..writeAsStringSync("test");

      // Multiple cookies - folded into a single header by package:http
      server.once(
        "POST",
        "api/part/attachment/",
        (_) => FakeResponse(
          201,
          body: {"pk": 1},
          setCookies: [
            "csrftoken=rotated-upload; Path=/",
            "extra=1; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/",
          ],
        ),
      );

      try {
        final response = await api.uploadFile("part/attachment/", file);
        expect(response.statusCode, equals(201));
      } finally {
        file.deleteSync();
      }

      final FakeRequest request = server
          .received("POST", "api/part/attachment/")
          .single;
      expect(request.cookies["sessionid"], isNotEmpty);
      expect(
        request.headers["x-csrftoken"],
        equals(request.cookies["csrftoken"]),
      );

      expect(api.session.csrfToken, equals("rotated-upload"));
      expect(api.session.cookieNames, contains("extra"));
    });

    test("Cookies rotated by the server are persisted", () async {
      server.once(
        "GET",
        "api/part/",
        (_) => FakeResponse(
          200,
          body: [],
          setCookies: ["csrftoken=rotated; Path=/"],
        ),
      );

      await api.get("part/");

      await eventually(
        () async => (await stored(profile)).csrfToken == "rotated",
      );
    });

    test("Downloads only send credentials to the server", () async {
      final FakeInvenTreeServer foreign = await FakeInvenTreeServer.start();

      // getTemporaryDirectory() is mocked to the working directory
      final List<String> files = [
        "inventree-auth-own.txt",
        "inventree-auth-foreign.txt",
      ];

      try {
        await api.downloadFile(
          "${server.url}media/${files[0]}",
          openOnDownload: false,
        );
        await api.downloadFile(
          "${foreign.url}media/${files[1]}",
          openOnDownload: false,
        );

        final FakeRequest own = server
            .received("GET", "media/${files[0]}")
            .single;
        expect(own.cookies["sessionid"], isNotEmpty);

        final FakeRequest other = foreign
            .received("GET", "media/${files[1]}")
            .single;
        expect(other.cookies, isEmpty);
        expect(other.headers.containsKey("x-csrftoken"), equals(false));
        expect(other.headers.containsKey("authorization"), equals(false));
      } finally {
        await foreign.close();

        for (final name in files) {
          final file = File(name);
          if (file.existsSync()) file.deleteSync();
        }
      }
    });
  });

  group("Profiles:", () {
    test("Switching profiles keeps sessions separate", () async {
      final FakeInvenTreeServer other = await FakeInvenTreeServer.start();

      try {
        final a = await fakeProfile(server, name: "${profileName} A");
        final b = await fakeProfile(other, name: "${profileName} B");

        await loginAndConnect(a);
        final String sessionA = server.sessions.keys.single;

        await loginAndConnect(b);
        final String sessionB = other.sessions.keys.single;

        expect(sessionA, isNot(equals(sessionB)));

        // Each profile retains its own session
        expect(
          (await stored(a)).cookieHeader(Uri.parse(server.url)),
          contains(sessionA),
        );
        expect(
          (await stored(b)).cookieHeader(Uri.parse(other.url)),
          contains(sessionB),
        );

        // Switch back to A, without logging in again
        final int before = server.requests.length;
        expect(await api.connectToServer(a), equals(true));
        await Future<void>.delayed(Duration(milliseconds: 200));

        for (final request in server.requests.skip(before)) {
          expect(request.cookies["sessionid"], equals(sessionA));
        }

        // B's session never reached server A (and vice versa)
        expect(
          server.requests.where((r) => r.cookies["sessionid"] == sessionB),
          isEmpty,
        );
        expect(
          other.requests.where((r) => r.cookies["sessionid"] == sessionA),
          isEmpty,
        );
      } finally {
        await other.close();
      }
    });

    test("Editing the server address discards the session", () async {
      // Another service on the same host, at a different port
      final FakeInvenTreeServer other = await FakeInvenTreeServer.start();

      try {
        final profile = await fakeProfile(server);
        await loginAndConnect(profile);
        api.disconnectFromServer();

        final String key = "profile_session_${profile.key}";

        profile.server = other.url;
        await manager.updateProfile(profile);

        final UserProfile edited = (await manager.getProfileByName(
          profileName,
        ))!;
        expect(edited.hasSession, equals(false));

        // Stored cookies have been removed
        expect(await const FlutterSecureStorage().read(key: key), isNull);

        // ... and are never sent to the new address
        expect(await api.connectToServer(edited), equals(false));

        for (final request in other.requests) {
          expect(request.cookies, isEmpty, reason: request.toString());
          expect(request.headers.containsKey("cookie"), equals(false));
        }
      } finally {
        await other.close();
      }
    });

    test(
      "Managed configuration changing the server discards the session",
      () async {
        final FakeInvenTreeServer other = await FakeInvenTreeServer.start();

        const String name = "${profileName} Managed Move";
        _profiles.add(name);

        try {
          await applyManagedConfiguration({"server": server.url, "name": name});

          UserProfile profile = (await manager.getProfileByName(name))!;
          expect((await login(profile)).authenticated, equals(true));
          expect((await stored(profile)).hasSession, equals(true));

          // Administrator moves the managed profile to a different address
          await applyManagedConfiguration({"server": other.url, "name": name});

          profile = (await manager.getProfileByName(name))!;
          expect(profile.server, equals(other.url));
          expect(profile.hasSession, equals(false));

          await api.beginAuthentication(profile);
          await api.connectToServer(profile);

          for (final request in other.requests) {
            expect(request.cookies, isEmpty, reason: request.toString());
          }
        } finally {
          await other.close();
        }
      },
    );

    test("Deleting a profile removes its secure storage", () async {
      final profile = await fakeProfile(server);
      expect((await login(profile)).authenticated, equals(true));

      final String key = "profile_session_${profile.key}";
      expect(await const FlutterSecureStorage().read(key: key), isNotNull);

      await manager.deleteProfile(profile);

      expect(await const FlutterSecureStorage().read(key: key), isNull);
    });

    test("Logout of an inactive profile", () async {
      final profile = await fakeProfile(server);
      expect((await login(profile)).authenticated, equals(true));

      // Add a "trusted device" cookie
      final session = await stored(profile);
      session.captureHeaders(Uri.parse(server.url), [
        "mfa_trusted=trusted; Path=/",
      ]);
      await manager.saveSession(profile, session);

      api.disconnectFromServer();

      await InvenTreeAuth().logout(profile);

      // Local only - the server is not contacted for an inactive profile
      expect(server.received("DELETE", "api/auth/v1/auth/session"), isEmpty);

      final SessionStore after = await stored(profile);
      expect(after.hasSession, equals(false));
      expect(after.hasCsrfToken, equals(false));
      expect(after.cookieNames, contains("mfa_trusted"));
      expect(profile.hasSession, equals(false));

      expect((await manager.getProfileByName(profileName))!.username, "user");
    });

    test("Logout with the server unreachable", () async {
      final profile = await fakeProfile(server);
      await loginAndConnect(profile);

      await server.close();

      await InvenTreeAuth().logout(profile);

      expect(api.isConnected(), equals(false));
      expect(profile.hasSession, equals(false));
      expect((await stored(profile)).hasSession, equals(false));
    });

    test("Managed configuration profile", () async {
      const String name = "${profileName} Managed";
      _profiles.add(name);

      await applyManagedConfiguration({
        "server": server.url,
        "name": name,
        // Pre-provisioned tokens are no longer supported, and must be ignored
        "token": "managed-token",
      });

      final UserProfile? profile = await manager.getProfileByName(name);
      expect(profile, isNotNull);
      expect(profile!.server, equals(server.url));
      expect(profile.hasSession, equals(false));
      expect(profile.toJson().containsKey("token"), equals(false));

      final Map<String, String> secure = await const FlutterSecureStorage()
          .readAll();
      expect(secure.values, isNot(contains("managed-token")));

      // The user must login themselves
      expect(await api.connectToServer(profile), equals(false));
      expect((await login(profile)).authenticated, equals(true));
    });
  });

  group("Storage failures:", () {
    test("Login fails if the session cannot be saved", () async {
      final profile = await fakeProfile(server);

      secureStorageFailures.addAll(["write", "delete"]);

      final AuthResult result = await login(profile);

      expect(result.status, equals(AuthStatus.failed));
      expect(result.errorMessage, equals(L10().sessionSaveFailed));
      expect(profile.hasSession, equals(false));

      // The new session is ended on the server, and discarded in memory
      expect(server.received("DELETE", "api/auth/v1/auth/session").length, 1);
      expect(server.sessions, isEmpty);
      expect(api.session.hasSession, equals(false));

      // The username is only remembered for a successful login
      expect((await manager.getProfileByName(profileName))!.username, isEmpty);

      // Once storage is available again, login succeeds
      secureStorageFailures.clear();
      expect((await login(profile)).authenticated, equals(true));
      expect((await stored(profile)).hasSession, equals(true));
    });

    test("MFA login fails if the session cannot be saved", () async {
      final profile = await fakeProfile(server);

      expect(
        (await login(profile, username: "mfa")).status,
        equals(AuthStatus.flowPending),
      );

      secureStorageFailures.addAll(["write", "delete"]);

      final AuthResult result = await InvenTreeAuth().submitMfaCode(
        server.validCode,
      );

      expect(result.status, equals(AuthStatus.failed));
      expect(result.errorMessage, equals(L10().sessionSaveFailed));
      expect(profile.hasSession, equals(false));
      expect(server.sessions, isEmpty);
    });

    test("Successful logout reports success", () async {
      final profile = await fakeProfile(server);
      await loginAndConnect(profile);

      expect(await InvenTreeAuth().logout(profile), equals(true));
      expect(profile.hasSession, equals(false));
    });

    test("Inactive profile logout reports failure", () async {
      final profile = await fakeProfile(server);
      expect((await login(profile)).authenticated, equals(true));
      api.disconnectFromServer();

      secureStorageFailures.addAll(["write", "delete"]);

      expect(await InvenTreeAuth().logout(profile), equals(false));

      // The (still valid) session remains stored - so is not reported as removed
      expect(profile.hasSession, equals(true));

      secureStorageFailures.clear();
      expect((await stored(profile)).hasSession, equals(true));

      // Retry succeeds
      expect(await InvenTreeAuth().logout(profile), equals(true));
      expect(profile.hasSession, equals(false));
      expect((await stored(profile)).hasSession, equals(false));
    });

    test("Offline logout reports failure", () async {
      final profile = await fakeProfile(server);
      await loginAndConnect(profile);

      await server.close();
      secureStorageFailures.addAll(["write", "delete"]);

      expect(await InvenTreeAuth().logout(profile), equals(false));
      expect(profile.hasSession, equals(true));
      expect(api.isConnected(), equals(false));

      secureStorageFailures.clear();
      expect((await stored(profile)).hasSession, equals(true));
    });

    test("Logout falls back to deleting all stored cookies", () async {
      final profile = await fakeProfile(server);
      expect((await login(profile)).authenticated, equals(true));

      // Add a "trusted device" cookie, so the jar is not empty after logout
      final session = await stored(profile);
      session.captureHeaders(Uri.parse(server.url), [
        "mfa_trusted=trusted; Path=/",
      ]);
      expect(await manager.saveSession(profile, session), equals(true));

      api.disconnectFromServer();

      // Cookies cannot be re-written, but can be deleted
      secureStorageFailures.add("write");

      expect(await InvenTreeAuth().logout(profile), equals(true));
      expect(profile.hasSession, equals(false));

      secureStorageFailures.clear();
      expect((await stored(profile)).isEmpty, equals(true));
    });

    test("Session expiry with storage failure", () async {
      final profile = await fakeProfile(server);
      await loginAndConnect(profile);

      server.endAllSessions();
      secureStorageFailures.addAll(["write", "delete"]);

      await api.get("part/");

      // The user is still directed to login - the stored copy is no longer valid
      expect(api.isConnected(), equals(false));
      expect(logged("Opening login screen"), equals(true));
      expect(
        logged("Expired session could not be removed from storage"),
        equals(true),
      );
    });
  });
}
