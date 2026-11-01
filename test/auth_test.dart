/*
 * Unit tests for session authentication (no server required)
 */

import "dart:io";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sembast/sembast.dart";

import "package:inventree/api.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/auth/session_store.dart";
import "package:inventree/inventree/redact.dart";
import "package:inventree/preferences.dart";
import "package:inventree/user_profile.dart";

import "setup.dart";

const String server = "https://inventree.example.com";

Cookie _cookie(
  String name,
  String value, {
  String? domain,
  String? path,
  int? maxAge,
  DateTime? expires,
  bool secure = false,
}) {
  final cookie = Cookie(name, value);
  cookie.domain = domain;
  cookie.path = path;
  cookie.maxAge = maxAge;
  cookie.expires = expires;
  cookie.secure = secure;
  return cookie;
}

void main() {
  setupTestEnv();

  final Uri serverUri = Uri.parse("${server}/api/part/");

  group("SessionStore:", () {
    test("Capture and send cookies", () {
      final store = SessionStore(server: server);

      store.capture(serverUri, [
        _cookie(SESSION_COOKIE_NAME, "abc", path: "/"),
        _cookie(CSRF_COOKIE_NAME, "xyz", path: "/"),
      ]);

      expect(store.hasSession, equals(true));
      expect(store.csrfToken, equals("xyz"));

      final String header = store.cookieHeader(serverUri);
      expect(header, contains("sessionid=abc"));
      expect(header, contains("csrftoken=xyz"));
    });

    test("Cookies are never accepted from or sent to another host", () {
      final store = SessionStore(server: server);

      // Cookie received from a different host
      store.capture(Uri.parse("https://evil.example.org/"), [
        _cookie(SESSION_COOKIE_NAME, "abc"),
      ]);

      expect(store.hasSession, equals(false));

      // Cookie for a domain the server does not belong to
      store.capture(serverUri, [
        _cookie(SESSION_COOKIE_NAME, "abc", domain: "other.com"),
      ]);

      expect(store.hasSession, equals(false));

      store.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "abc")]);
      expect(store.hasSession, equals(true));

      expect(store.cookieHeader(Uri.parse("https://evil.example.org/")), "");

      // Same host, different scheme / port
      expect(
        store.cookieHeader(Uri.parse("http://inventree.example.com/")),
        "",
      );
      expect(
        store.cookieHeader(Uri.parse("https://inventree.example.com:8443/")),
        "",
      );
    });

    test("Expiry and deletion", () {
      final store = SessionStore(server: server);

      store.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "abc")]);
      expect(store.hasSession, equals(true));

      // Max-Age=0 deletes the cookie
      store.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "", maxAge: 0)]);
      expect(store.hasSession, equals(false));

      // Expires in the past deletes the cookie
      store.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "abc")]);
      store.capture(serverUri, [
        _cookie(SESSION_COOKIE_NAME, "abc", expires: DateTime(1970)),
      ]);
      expect(store.hasSession, equals(false));
    });

    test("Secure cookies are not sent over HTTP", () {
      final store = SessionStore(server: "http://inventree.local");
      final uri = Uri.parse("http://inventree.local/api/");

      store.capture(uri, [
        _cookie(SESSION_COOKIE_NAME, "abc", secure: true),
        _cookie(CSRF_COOKIE_NAME, "xyz"),
      ]);

      expect(store.cookieHeader(uri), equals("csrftoken=xyz"));
    });

    test("Path matching", () {
      final store = SessionStore(server: server);

      store.capture(serverUri, [_cookie("scoped", "1", path: "/api")]);

      expect(store.cookieHeader(Uri.parse("${server}/api/part/")), "scoped=1");
      expect(store.cookieHeader(Uri.parse("${server}/api")), "scoped=1");
      expect(store.cookieHeader(Uri.parse("${server}/apix/")), "");
      expect(store.cookieHeader(Uri.parse("${server}/web/")), "");
    });

    test("Change notification", () {
      final store = SessionStore(server: server);

      int changes = 0;
      store.onChanged = () => changes++;

      store.capture(serverUri, [_cookie(CSRF_COOKIE_NAME, "xyz", maxAge: 60)]);
      expect(changes, equals(1));

      // Same value (and similar expiry) - no change reported
      store.capture(serverUri, [_cookie(CSRF_COOKIE_NAME, "xyz", maxAge: 61)]);
      expect(changes, equals(1));

      // New value
      store.capture(serverUri, [_cookie(CSRF_COOKIE_NAME, "abc", maxAge: 60)]);
      expect(changes, equals(2));
    });

    test("Clear auth cookies retains other cookies", () {
      final store = SessionStore(server: server);

      store.capture(serverUri, [
        _cookie(SESSION_COOKIE_NAME, "abc"),
        _cookie(CSRF_COOKIE_NAME, "xyz"),
        _cookie("mfa_trusted", "trusted"),
      ]);

      store.clearAuthCookies();

      expect(store.hasSession, equals(false));
      expect(store.hasCsrfToken, equals(false));
      expect(store.cookieHeader(serverUri), equals("mfa_trusted=trusted"));

      store.clear();
      expect(store.isEmpty, equals(true));
    });

    test("Serialization", () {
      final store = SessionStore(server: server);

      store.capture(serverUri, [
        _cookie(SESSION_COOKIE_NAME, "abc", maxAge: 3600),
        _cookie(CSRF_COOKIE_NAME, "xyz", secure: true),
        _cookie("expired", "old", expires: DateTime(1970)),
      ]);

      final restored = SessionStore.fromJson(server, store.toJson());

      expect(restored.hasSession, equals(true));
      expect(restored.csrfToken, equals("xyz"));
      expect(restored.cookieNames.length, equals(2));

      // Corrupt data results in an empty store
      expect(SessionStore.fromJson(server, "not-json").isEmpty, equals(true));
      expect(SessionStore.fromJson(server, null).isEmpty, equals(true));
    });

    test("Server origin", () {
      expect(
        serverOrigin("https://inventree.example.com"),
        equals("https://inventree.example.com:443"),
      );
      expect(
        serverOrigin("HTTPS://InvenTree.Example.com:443/inventree/"),
        equals("https://inventree.example.com:443"),
      );
      expect(
        serverOrigin("http://127.0.0.1:8000/"),
        equals("http://127.0.0.1:8000"),
      );
      expect(serverOrigin("not a url"), isEmpty);
      expect(serverOrigin(""), isEmpty);
    });

    test("Stored cookies are only restored for the issuing origin", () {
      final store = SessionStore(server: server);
      store.capture(serverUri, [
        _cookie(SESSION_COOKIE_NAME, "abc"),
        _cookie(CSRF_COOKIE_NAME, "xyz"),
        _cookie("mfa_trusted", "trusted"),
      ]);

      final String data = store.toJson();

      // Same origin - including an explicit default port, a different path or case
      for (final address in [
        server,
        "https://inventree.example.com:443",
        "https://inventree.example.com/inventree/",
        "https://INVENTREE.example.com/",
      ]) {
        final restored = SessionStore.fromJson(address, data);
        expect(restored.rejected, equals(false), reason: address);
        expect(restored.hasSession, equals(true), reason: address);
      }

      // Different origin - no cookies at all are restored (including MFA trust)
      for (final address in [
        "http://inventree.example.com",
        "https://inventree.example.com:8443",
        "http://inventree.example.com:443",
        "https://other.example.com",
        "https://example.com",
        "",
      ]) {
        final restored = SessionStore.fromJson(address, data);
        expect(restored.rejected, equals(true), reason: address);
        expect(restored.isEmpty, equals(true), reason: address);
        expect(
          restored.cookieHeader(Uri.parse("${address}/api/")),
          isEmpty,
          reason: address,
        );
      }
    });

    test("Stored cookies without an origin are not restored", () {
      // Format used before the origin was recorded
      const String legacy =
          '[{"name": "sessionid", "value": "abc", "domain": "inventree.example.com"}]';

      final restored = SessionStore.fromJson(server, legacy);

      expect(restored.rejected, equals(true));
      expect(restored.isEmpty, equals(true));

      expect(
        SessionStore.fromJson(server, '{"cookies": []}').rejected,
        equals(true),
      );
    });

    test("Set-Cookie header parsing", () {
      // package:http folds multiple headers into one, separated by a comma
      final values = splitSetCookieHeader(
        [
          "sessionid=abc; expires=Thu, 01 Jan 2099 00:00:00 GMT; HttpOnly; Path=/",
          "csrftoken=xyz; expires=Fri, 02 Jan 2099 00:00:00 GMT; Path=/",
        ].join(","),
      );

      expect(values.length, equals(2));
      expect(values[0], startsWith("sessionid=abc"));
      expect(values[1], startsWith("csrftoken=xyz"));

      final store = SessionStore(server: server);

      // A malformed cookie does not prevent the others from being stored
      store.captureHeaders(serverUri, [...values, "=bad=;;"]);

      expect(store.hasSession, equals(true));
      expect(store.csrfToken, equals("xyz"));
    });
  });

  group("Request headers:", () {
    final api = InvenTreeAPI();

    setUp(() {
      api.profile = UserProfile(name: "Test", server: server);

      api.session = SessionStore(server: server);
      api.session.capture(serverUri, [
        _cookie(SESSION_COOKIE_NAME, "abc"),
        _cookie(CSRF_COOKIE_NAME, "xyz"),
      ]);
    });

    tearDown(() {
      api.disconnectFromServer();
    });

    test("Safe requests include cookies but not CSRF headers", () {
      final headers = api.defaultHeaders(url: "part/");

      expect(headers[HttpHeaders.cookieHeader], contains("sessionid=abc"));
      expect(headers.containsKey("X-CSRFToken"), equals(false));
      expect(headers.containsKey(HttpHeaders.authorizationHeader), false);
    });

    test("Unsafe requests include CSRF headers", () {
      for (final method in ["POST", "PUT", "PATCH", "DELETE"]) {
        final headers = api.defaultHeaders(method: method, url: "part/");

        expect(headers["X-CSRFToken"], equals("xyz"));
        expect(headers["Origin"], equals(server));
        expect(headers[HttpHeaders.refererHeader], equals("${server}/"));
      }
    });

    test("No credentials for other hosts", () {
      final headers = api.defaultHeaders(
        method: "POST",
        url: "https://images.example.org/image.png",
      );

      expect(headers.containsKey(HttpHeaders.cookieHeader), equals(false));
      expect(headers.containsKey("X-CSRFToken"), equals(false));
      expect(headers.containsKey("Origin"), equals(false));
    });
  });

  group("Error reporting:", () {
    test("Credentials are redacted", () {
      final String result = redactHeaders({
        "Cookie": "sessionid=abc",
        "set-cookie": "sessionid=abc",
        "X-CSRFToken": "xyz",
        "Authorization": "Token 123",
        "Accept": "application/json",
      });

      expect(result, isNot(contains("abc")));
      expect(result, isNot(contains("xyz")));
      expect(result, isNot(contains("123")));
      expect(result, contains("application/json"));
    });
  });

  group("AuthResult:", () {
    APIResponse response(int status, Map<String, dynamic> data) =>
        APIResponse(statusCode: status, data: data);

    test("Authenticated", () {
      final result = AuthResult.fromResponse(
        response(200, {
          "status": 200,
          "data": {
            "user": {"id": 1, "username": "admin"},
          },
          "meta": {"is_authenticated": true},
        }),
      );

      expect(result.status, equals(AuthStatus.authenticated));
      expect(result.user["username"], equals("admin"));
    });

    test("MFA required", () {
      final result = AuthResult.fromResponse(
        response(401, {
          "status": 401,
          "data": {
            "flows": [
              {"id": "login"},
              {
                "id": "mfa_authenticate",
                "is_pending": true,
                "types": ["totp", "recovery_codes"],
              },
            ],
          },
          "meta": {"is_authenticated": false},
        }),
      );

      expect(result.status, equals(AuthStatus.flowPending));
      expect(result.pendingFlow!.id, equals(FLOW_MFA_AUTHENTICATE));
      expect(result.pendingFlow!.isSupportedMfa, equals(true));
      expect(result.pendingFlow!.supportsRecoveryCodes, equals(true));
    });

    test("Unsupported MFA types", () {
      final flow = AuthFlow.fromJson({
        "id": "mfa_authenticate",
        "is_pending": true,
        "types": ["webauthn"],
      });

      expect(flow.isSupportedMfa, equals(false));
    });

    test("Invalid credentials", () {
      final result = AuthResult.fromResponse(
        response(400, {
          "status": 400,
          "errors": [
            {
              "message":
                  "The username and/or password you specified are not correct.",
              "code": "username_password_mismatch",
            },
          ],
        }),
      );

      expect(result.status, equals(AuthStatus.failed));
      expect(result.errorMessage, contains("not correct"));
    });

    test("Not authenticated, no pending flow", () {
      final result = AuthResult.fromResponse(
        response(401, {
          "status": 401,
          "data": {
            "flows": [
              {"id": "login"},
            ],
          },
          "meta": {"is_authenticated": false},
        }),
      );

      expect(result.status, equals(AuthStatus.failed));
    });

    test("No response", () {
      final result = AuthResult.fromResponse(APIResponse());

      expect(result.status, equals(AuthStatus.failed));
      expect(result.statusCode, equals(-1));
    });

    test("Config", () {
      final config = AuthConfig.fromResponse(
        response(200, {
          "status": 200,
          "data": {
            "account": {
              "login_methods": ["email"],
            },
            "mfa": {
              "supported_types": ["totp", "recovery_codes", "webauthn"],
            },
            "socialaccount": {
              "providers": [
                {
                  "id": "google",
                  "name": "Google",
                  "flows": ["provider_redirect", "provider_token"],
                  "client_id": "123.apps.googleusercontent.com",
                },
              ],
            },
          },
        }),
      );

      expect(config.loginField, equals("email"));
      expect(config.mfaTypes.length, equals(3));
      expect(config.providers.first.supportsTokenLogin, equals(true));

      // Fallback to username for an invalid response
      expect(AuthConfig.fromResponse(APIResponse()).loginField, "username");
    });
  });

  group("UserProfile session storage:", () {
    test("Save, load and clear", () async {
      final manager = UserProfileDBManager();

      final profile = UserProfile(name: "Session Test", server: server);
      await manager.addProfile(profile);

      final session = SessionStore(server: server);
      session.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "abc")]);

      await manager.saveSession(profile, session);

      final loaded = await manager.getProfileByName("Session Test");
      expect(loaded!.hasSession, equals(true));
      expect((await manager.loadSession(loaded)).hasSession, equals(true));

      // The session must never be stored in the plain profile record
      expect(loaded.toJson().toString(), isNot(contains("abc")));

      await manager.clearSession(loaded);
      expect((await manager.loadSession(loaded)).hasSession, equals(false));

      await manager.deleteProfile(loaded);
    });

    test("Legacy API tokens are removed", () async {
      final manager = UserProfileDBManager();
      final db = await InvenTreePreferencesDB.instance.database;
      const storage = FlutterSecureStorage();

      // Profile as stored by an older version of the app
      final int key =
          (await manager.store.add(db, {
                "name": "Legacy Profile",
                "server": server,
                "token": "legacy-plaintext-token",
              }))!
              as int;

      await storage.write(key: "profile_token_${key}", value: "legacy-token");

      await InvenTreeSettingsManager().setValue("legacy_tokens_removed", false);
      await manager.migrateLegacyTokens();

      expect(await storage.read(key: "profile_token_${key}"), isNull);

      final record = (await manager.store.record(key).get(db))! as Map;
      expect(record.containsKey("token"), equals(false));
      expect(record["name"], equals("Legacy Profile"));

      await manager.store.record(key).delete(db);
    });

    test("Legacy token migration retries after a storage failure", () async {
      final manager = UserProfileDBManager();
      final db = await InvenTreePreferencesDB.instance.database;
      const storage = FlutterSecureStorage();

      final List<int> keys = [];

      for (final name in ["Legacy Retry A", "Legacy Retry B"]) {
        keys.add(
          (await manager.store.add(db, {
                "name": name,
                "server": server,
                "token": "legacy-plaintext-token",
              }))!
              as int,
        );
      }

      for (final key in keys) {
        await storage.write(key: "profile_token_${key}", value: "legacy-token");
      }

      await InvenTreeSettingsManager().setValue("legacy_tokens_removed", false);

      // Secure storage deletion fails
      secureStorageFailures.add("delete");

      try {
        await manager.migrateLegacyTokens();
      } finally {
        secureStorageFailures.clear();
      }

      // Migration is not marked complete, so runs again on next startup
      expect(
        await InvenTreeSettingsManager().getBool(
          "legacy_tokens_removed",
          false,
        ),
        equals(false),
      );

      // Plaintext tokens are still stripped from *all* profiles in the meantime
      for (final key in keys) {
        final record = (await manager.store.record(key).get(db))! as Map;
        expect(record.containsKey("token"), equals(false));
        expect(await storage.read(key: "profile_token_${key}"), isNotNull);
      }

      // Next startup - storage is available again
      await manager.migrateLegacyTokens();

      for (final key in keys) {
        expect(await storage.read(key: "profile_token_${key}"), isNull);
      }

      expect(
        await InvenTreeSettingsManager().getBool(
          "legacy_tokens_removed",
          false,
        ),
        equals(true),
      );

      for (final key in keys) {
        await manager.store.record(key).delete(db);
      }
    });

    test("Startup cleanup removes legacy tokens for existing profiles", () async {
      final manager = UserProfileDBManager();
      const storage = FlutterSecureStorage();

      final profile = UserProfile(name: "Legacy Cleanup", server: server);
      await manager.addProfile(profile);

      final loaded = (await manager.getProfileByName("Legacy Cleanup"))!;

      // Token left behind for an existing profile (e.g. migration could not remove it)
      await storage.write(
        key: "profile_token_${loaded.key}",
        value: "legacy-token",
      );

      // ... alongside the profile's (valid) session
      final session = SessionStore(server: server);
      session.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "abc")]);
      await manager.saveSession(loaded, session);

      // Token for a profile which no longer exists
      await storage.write(key: "profile_token_99998", value: "legacy-token");

      await manager.removeOrphanedSessions();

      expect(await storage.read(key: "profile_token_${loaded.key}"), isNull);
      expect(await storage.read(key: "profile_token_99998"), isNull);

      // The session for the existing profile is retained
      expect((await manager.loadSession(loaded)).hasSession, equals(true));

      await manager.deleteProfile(loaded);
    });

    test("Logout keeps the username", () async {
      final manager = UserProfileDBManager();

      final profile = UserProfile(
        name: "Username Test",
        server: server,
        username: "alice",
      );
      await manager.addProfile(profile);

      final session = SessionStore(server: server);
      session.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "abc")]);
      await manager.saveSession(profile, session);

      await InvenTreeAuth().logout(profile);

      final loaded = await manager.getProfileByName("Username Test");
      expect(loaded!.username, equals("alice"));
      expect(loaded.hasSession, equals(false));

      // The password is never part of the profile
      expect(loaded.toJson().keys, isNot(contains("password")));

      await manager.deleteProfile(loaded);
    });

    test("Orphaned sessions are removed", () async {
      final manager = UserProfileDBManager();
      const storage = FlutterSecureStorage();

      final profile = UserProfile(name: "Orphan Test", server: server);
      await manager.addProfile(profile);

      final session = SessionStore(server: server);
      session.capture(serverUri, [_cookie(SESSION_COOKIE_NAME, "abc")]);
      await manager.saveSession(profile, session);

      // Left behind by a profile which no longer exists (e.g. before a reinstall)
      await storage.write(key: "profile_session_99999", value: "[]");
      await storage.write(key: "profile_token_99999", value: "legacy-token");

      // Unrelated entries are not touched
      await storage.write(key: "other_value", value: "keep");

      await manager.removeOrphanedSessions();

      expect(await storage.read(key: "profile_session_99999"), isNull);
      expect(await storage.read(key: "profile_token_99999"), isNull);
      expect(await storage.read(key: "other_value"), equals("keep"));
      expect((await manager.loadSession(profile)).hasSession, equals(true));

      await storage.delete(key: "other_value");
      await manager.deleteProfile(profile);
    });
  });
}
