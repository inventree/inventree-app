/*
 * Tests for removal of credentials from error reports (sentry.io)
 */

import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:sentry_flutter/sentry_flutter.dart";

import "package:inventree/inventree/redact.dart";

// Credentials which must never appear in an error report
const List<String> secrets = [
  "SESSION-SECRET-1",
  "CSRF-SECRET-2",
  "hunter2-password",
  "inv-0123456789abcdef0123456789abcdef01234567-20261101",
  "TRUST-SECRET-3",
  "url-pass-4",
  "query-token-5",
  // Second word of a password containing whitespace
  "SECOND-WORD-6",
  // Password with a leading space
  "LEADING-SPACE-7",
];

/*
 * Captures (serialized) envelopes instead of sending them to sentry.io
 */
class CapturingTransport implements Transport {
  CapturingTransport(this.options);

  final SentryOptions options;

  final List<String> sent = [];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final bytes = <int>[];

    await for (final chunk in envelope.envelopeStream(options)) {
      bytes.addAll(chunk);
    }

    sent.add(utf8.decode(bytes));

    return SentryId.newId();
  }
}

void expectNoSecrets(String text) {
  for (final secret in secrets) {
    expect(text, isNot(contains(secret)), reason: "Leaked: ${secret}");
  }
}

void main() {
  group("redactString:", () {
    final Map<String, String> cases = {
      "Cookie: sessionid=SESSION-SECRET-1; csrftoken=CSRF-SECRET-2":
          "Cookie: <redacted>",
      "set-cookie: sessionid=SESSION-SECRET-1; Path=/":
          "set-cookie: <redacted>",
      "Authorization: Token inv-0123456789abcdef0123456789abcdef01234567-20261101":
          "Authorization: <redacted>",
      "X-CSRFToken: CSRF-SECRET-2": "X-CSRFToken: <redacted>",
      "sent sessionid=SESSION-SECRET-1 to server":
          "sent sessionid=<redacted> to server",
      "mfa_trusted=TRUST-SECRET-3": "mfa_trusted=<redacted>",
      '{"username": "user", "password": "hunter2-password"}':
          '{"username": "user", "password": "<redacted>"}',
      "{username: user, password: hunter2-password}":
          "{username: user, password: <redacted>}",
      "header Bearer abc123def456ghi": "header Bearer <redacted>",
      "token inv-0123456789abcdef0123456789abcdef01234567-20261101 used":
          "token <redacted> used",
      "https://admin:url-pass-4@example.com/api/":
          "https://<redacted>@example.com/api/",
      "https://example.com/api/?limit=10&token=query-token-5&offset=0":
          "https://example.com/api/?limit=10&token=<redacted>&offset=0",
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(redactString(entry.key), equals(entry.value));
      });
    }

    // Values containing whitespace, delimiters or escaped quotes must be
    // redacted entirely - not just up to the first space / delimiter
    final Map<String, String> quoted = {
      // Whitespace
      '{"password": "first second"}': '{"password": "<redacted>"}',
      '{"password": " leading-space"}': '{"password": "<redacted>"}',
      '{"password": "trailing-space "}': '{"password": "<redacted>"}',
      '{"password": "  "}': '{"password": "<redacted>"}',
      '{"password": "tab\tand\nnewline"}': '{"password": "<redacted>"}',
      // Delimiters
      '{"password": "a,b;c&d}e]f", "username": "user"}':
          '{"password": "<redacted>", "username": "user"}',
      '{"password": "key: value, other: 1"}': '{"password": "<redacted>"}',
      // Escaped quotes and backslashes
      r'{"password": "a\"b c\"d", "username": "user"}':
          '{"password": "<redacted>", "username": "user"}',
      r'{"password": "ends with backslash\\", "username": "user"}':
          '{"password": "<redacted>", "username": "user"}',
      // Single quotes (e.g. Python repr)
      "{'password': 'first second', 'username': 'user'}":
          "{'password': '<redacted>', 'username': 'user'}",
      r"{'password': 'it\'s a secret'}": "{'password': '<redacted>'}",
      // Unquoted (e.g. Dart Map.toString())
      "{password: first second, username: user}":
          "{password: <redacted>, username: user}",
      "{username: user, password: first second}":
          "{username: user, password: <redacted>}",
      // Pretty-printed JSON
      '{\n  "password": "first second",\n  "username": "user"\n}':
          '{\n  "password": "<redacted>",\n  "username": "user"\n}',
      // Truncated data - unterminated value is redacted to the end
      '{"username": "user", "password": "first second third':
          '{"username": "user", "password": "<redacted>',
      // key=value forms
      'password="first second" next=1': 'password="<redacted>" next=1',
      "token='a b' next=1": "token='<redacted>' next=1",
      "password=first+second&next=1": "password=<redacted>&next=1",
      // Headers with quoted values
      r'"Cookie": "a=\"b c\"; sessionid=SESSION-SECRET-1", "Accept": "json"':
          '"Cookie": "<redacted>", "Accept": "json"',
      '"Authorization": "Token abc def", "Accept": "json"':
          '"Authorization": "<redacted>", "Accept": "json"',
    };

    for (final entry in quoted.entries) {
      test("Quoted: ${entry.key}", () {
        expect(redactString(entry.key), equals(entry.value));
      });
    }

    test("Ordinary text is unchanged", () {
      for (final text in [
        "Server error at http://127.0.0.1:8000/api/part/?limit=10&offset=20",
        "Session expired - please login again",
        "Token authentication has been removed",
        "SocketException: Connection refused (OS Error: errno = 111)",
        "API : Opening login screen for 'My Server'",
      ]) {
        expect(redactString(text), equals(text));
      }
    });
  });

  test("redactValue removes sensitive keys", () {
    final dynamic result = redactValue({
      "url": "/api/part/",
      "requestHeaders": "Cookie: sessionid=SESSION-SECRET-1",
      "csrfToken": "CSRF-SECRET-2",
      "nested": {
        "password": "hunter2-password",
        "items": [
          "ok",
          {"sessionid": "SESSION-SECRET-1"},
        ],
      },
      "statusCode": 500,
    });

    expectNoSecrets(result.toString());
    expect(result["url"], equals("/api/part/"));
    expect(result["statusCode"], equals(500));
    expect(result["nested"]["items"][0], equals("ok"));
  });

  test("redactHeaders", () {
    final String result = redactHeaders({
      "Cookie": "sessionid=SESSION-SECRET-1",
      "X-CSRFToken": "CSRF-SECRET-2",
      "Accept": "application/json",
    });

    expectNoSecrets(result);
    expect(result, contains("Accept: application/json"));
  });

  test("redactSentryEvent", () {
    final event = SentryEvent(
      message: SentryMessage("Login failed: password=hunter2-password"),
      exceptions: [
        SentryException(
          type: "HttpException",
          value: "Cookie: sessionid=SESSION-SECRET-1",
        ),
      ],
      tags: {"csrftoken": "CSRF-SECRET-2", "server": "example.com"},
      breadcrumbs: [
        Breadcrumb(message: "DEBUG: mfa_trusted=TRUST-SECRET-3"),
        Breadcrumb(data: {"token": "query-token-5"}),
      ],
      request: SentryRequest(
        url: "https://admin:url-pass-4@example.com/api/",
        queryString: "token=query-token-5",
        headers: {
          "Cookie": "sessionid=SESSION-SECRET-1",
          "Accept": "application/json",
        },
        data: {"password": "hunter2-password"},
      ),
    );

    event.contexts["context"] = {
      "requestHeaders": "X-CSRFToken: CSRF-SECRET-2",
      "responseData": '{"detail": "error", "token": "query-token-5"}',
      "url": "/api/part/",
    };
    event.contexts["stacktrace"] = "at login (sessionid=SESSION-SECRET-1)";

    final SentryEvent result = redactSentryEvent(event);

    expectNoSecrets(jsonEncode(result.toJson()));

    // Useful information is retained
    expect(result.tags!["server"], equals("example.com"));
    expect(result.request!.headers["Accept"], equals("application/json"));
    expect((result.contexts["context"] as Map)["url"], equals("/api/part/"));
  });

  test("Nothing sent to sentry.io contains credentials", () async {
    late CapturingTransport transport;

    await Sentry.init((options) {
      options.dsn = "https://public@sentry.example.com/1";

      transport = CapturingTransport(options);
      options.transport = transport;

      configureSentryPrivacy(options);
    });

    try {
      // As reported by the app (see sentryReportMessage / sentryReportError)
      Sentry.configureScope((scope) {
        scope.setContexts("context", {
          "requestHeaders":
              "Cookie: sessionid=SESSION-SECRET-1; csrftoken=CSRF-SECRET-2",
          "responseHeaders": "set-cookie: mfa_trusted=TRUST-SECRET-3; Path=/",
          "responseData":
              '{"password": "hunter2-password", "secret": "first SECOND-WORD-6"}',
          "url": "https://example.com/api/?token=query-token-5",
        });
      });

      Sentry.addBreadcrumb(
        Breadcrumb(
          message:
              "DEBUG: Authorization: Token inv-0123456789abcdef0123456789abcdef01234567-20261101",
        ),
      );

      await Sentry.captureMessage(
        "Server error at https://admin:url-pass-4@example.com/",
      );

      await Sentry.captureException(
        Exception(
          'Request failed - Cookie: sessionid=SESSION-SECRET-1 - {"password": " LEADING-SPACE-7"}',
        ),
        stackTrace: StackTrace.current,
      );

      expect(transport.sent.length, equals(2));

      for (final envelope in transport.sent) {
        expectNoSecrets(envelope);
        expect(envelope, contains(REDACTED));
      }
    } finally {
      await Sentry.close();
    }
  });
}
