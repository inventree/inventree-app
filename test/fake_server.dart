/*
 * A minimal in-process InvenTree server, for testing authentication
 * without a running server.
 *
 * Implements just enough of the InvenTree API and the allauth "headless"
 * (browser client) API to connect, login (optionally with MFA) and logout,
 * including session and CSRF cookie handling.
 *
 * Individual endpoints can be overridden (once, or always) to simulate
 * error conditions, and all received requests are recorded.
 */

import "dart:async";
import "dart:convert";
import "dart:io";

class FakeRequest {
  FakeRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.cookies,
    required this.body,
  });

  final String method;
  final String path;

  // Header names are lower case
  final Map<String, String> headers;
  final Map<String, String> cookies;
  final String body;

  Map<String, dynamic> get json {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  String toString() => "${method} ${path}";
}

class FakeResponse {
  FakeResponse(
    this.status, {
    this.body,
    this.setCookies = const [],
    this.dropConnection = false,
  });

  // Close the connection without sending a response
  FakeResponse.drop() : this(0, dropConnection: true);

  final int status;
  final Object? body;
  final List<String> setCookies;
  final bool dropConnection;
}

typedef FakeHandler = FutureOr<FakeResponse> Function(FakeRequest request);

class FakeInvenTreeServer {
  FakeInvenTreeServer._(this._server, this.apiVersion);

  static Future<FakeInvenTreeServer> start({int apiVersion = 568}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeInvenTreeServer._(server, apiVersion);

    server.listen(fake._handle);

    return fake;
  }

  final HttpServer _server;

  final int apiVersion;

  String get url => "http://127.0.0.1:${_server.port}/";

  // Accepted credentials (username -> password)
  final Map<String, String> users = {"user": "password", "mfa": "password"};

  // Users which require a TOTP code after their password
  final Set<String> mfaUsers = {"mfa"};

  // TOTP code accepted for MFA users
  String validCode = "123456";

  // Login methods reported by auth/v1/config
  List<String> loginMethods = ["username"];

  // Requests received, in order
  final List<FakeRequest> requests = [];

  // Active sessions (session ID -> username)
  final Map<String, String> sessions = {};

  // Partially authenticated sessions, waiting for an MFA code
  final Map<String, String> _pending = {};

  int _counter = 0;

  final Map<String, List<FakeHandler>> _once = {};
  final Map<String, FakeHandler> _always = {};

  Future<void> close() => _server.close(force: true);

  // Override the next request for [method] [path] (path relative to the server root)
  void once(String method, String path, FakeHandler handler) {
    _once.putIfAbsent("${method} /${path}", () => []).add(handler);
  }

  // Override all requests for [method] [path]
  void always(String method, String path, FakeHandler handler) {
    _always["${method} /${path}"] = handler;
  }

  // Requests received for [method] [path]
  List<FakeRequest> received(String method, String path) => requests
      .where((r) => r.method == method && r.path == "/${path}")
      .toList();

  // End all sessions (e.g. expired, or ended from another device)
  void endAllSessions() {
    sessions.clear();
    _pending.clear();
  }

  String _newId(String prefix) {
    _counter++;
    return "${prefix}-${_server.port}-${_counter}";
  }

  Future<void> _handle(HttpRequest request) async {
    final Map<String, String> headers = {};

    request.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(", ");
    });

    final Map<String, String> cookies = {};

    for (final cookie in request.cookies) {
      cookies[cookie.name] = cookie.value;
    }

    final fake = FakeRequest(
      method: request.method,
      path: request.uri.path,
      headers: headers,
      cookies: cookies,
      body: await utf8.decoder.bind(request).join(),
    );

    requests.add(fake);

    final String key = "${fake.method} ${fake.path}";

    FakeResponse response;

    if (_once[key]?.isNotEmpty ?? false) {
      response = await _once[key]!.removeAt(0)(fake);
    } else if (_always.containsKey(key)) {
      response = await _always[key]!(fake);
    } else {
      response = _default(fake);
    }

    if (response.dropConnection) {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }

    request.response.statusCode = response.status;
    request.response.headers.contentType = ContentType.json;

    for (final cookie in response.setCookies) {
      request.response.headers.add(HttpHeaders.setCookieHeader, cookie);
    }

    if (response.body != null) {
      request.response.write(jsonEncode(response.body));
    }

    await request.response.close();
  }

  String? _user(FakeRequest request) =>
      sessions[request.cookies["sessionid"] ?? ""];

  // Django CSRF check for "unsafe" requests
  bool _csrfValid(FakeRequest request) {
    final String cookie = request.cookies["csrftoken"] ?? "";

    return cookie.isNotEmpty &&
        request.headers["x-csrftoken"] == cookie &&
        request.headers["origin"] == Uri.parse(url).origin;
  }

  Map<String, dynamic> _authenticated(String username) => {
    "status": 200,
    "data": {
      "user": {"username": username},
      "methods": [],
    },
    "meta": {"is_authenticated": true},
  };

  Map<String, dynamic> _flows({bool mfaPending = false}) => {
    "status": 401,
    "data": {
      "flows": [
        {"id": "login"},
        if (mfaPending)
          {
            "id": "mfa_authenticate",
            "is_pending": true,
            "types": ["totp", "recovery_codes"],
          },
      ],
    },
    "meta": {"is_authenticated": false},
  };

  // Start a new (authenticated) session, rotating the CSRF token as Django does
  FakeResponse _login(String username) {
    final String sessionId = _newId("session");
    sessions[sessionId] = username;

    return FakeResponse(
      200,
      body: _authenticated(username),
      setCookies: [
        "sessionid=${sessionId}; HttpOnly; Path=/; SameSite=Lax",
        "csrftoken=${_newId("csrf")}; Path=/; SameSite=Lax",
      ],
    );
  }

  FakeResponse _default(FakeRequest request) {
    final bool unsafe = !["GET", "HEAD", "OPTIONS"].contains(request.method);

    if (unsafe && !_csrfValid(request)) {
      return FakeResponse(
        403,
        body: {"detail": "CSRF Failed: CSRF token missing."},
      );
    }

    final String? user = _user(request);

    switch ("${request.method} ${request.path}") {
      case "GET /api/":
        return FakeResponse(
          200,
          body: {
            "server": "InvenTree",
            "version": "1.0.0",
            "instance": "Fake Server",
            "apiVersion": apiVersion,
          },
        );
      case "GET /api/auth/v1/config":
        return FakeResponse(
          200,
          body: {
            "status": 200,
            "data": {
              "account": {"login_methods": loginMethods},
              "socialaccount": {"providers": []},
              "mfa": {
                "supported_types": ["totp", "recovery_codes"],
              },
            },
          },
        );
      case "GET /api/auth/v1/auth/session":
        if (user != null) {
          return FakeResponse(200, body: _authenticated(user));
        }

        // Issue a CSRF token, if the client does not already have one
        return FakeResponse(
          401,
          body: _flows(),
          setCookies: request.cookies.containsKey("csrftoken")
              ? []
              : ["csrftoken=${_newId("csrf")}; Path=/; SameSite=Lax"],
        );
      case "DELETE /api/auth/v1/auth/session":
        sessions.remove(request.cookies["sessionid"]);

        return FakeResponse(
          401,
          body: _flows(),
          setCookies: [
            "sessionid=; expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=0; Path=/",
          ],
        );
      case "POST /api/auth/v1/auth/login":
        final Map<String, dynamic> data = request.json;
        final String login = (data["username"] ?? data["email"] ?? "")
            .toString();

        if (!users.containsKey(login) || users[login] != data["password"]) {
          return FakeResponse(
            400,
            body: {
              "status": 400,
              "errors": [
                {
                  "message":
                      "The username and/or password you specified are not correct.",
                  "code": "username_password_mismatch",
                  "param": "password",
                },
              ],
            },
          );
        }

        if (mfaUsers.contains(login)) {
          final String pendingId = _newId("pending");
          _pending[pendingId] = login;

          return FakeResponse(
            401,
            body: _flows(mfaPending: true),
            setCookies: ["sessionid=${pendingId}; HttpOnly; Path=/"],
          );
        }

        return _login(login);
      case "POST /api/auth/v1/auth/2fa/authenticate":
        final String? pendingUser = _pending[request.cookies["sessionid"]];

        if (pendingUser == null) {
          return FakeResponse(409, body: {"status": 409});
        }

        if (request.json["code"] != validCode) {
          return FakeResponse(
            400,
            body: {
              "status": 400,
              "errors": [
                {"message": "Incorrect code.", "code": "incorrect_code"},
              ],
            },
          );
        }

        _pending.remove(request.cookies["sessionid"]);

        return _login(pendingUser);
      case "GET /api/user/me/":
        if (user == null) {
          return _unauthenticated();
        }

        return FakeResponse(200, body: {"pk": 1, "username": user});
      case "GET /api/user/me/roles/":
        if (user == null) {
          return _unauthenticated();
        }

        return FakeResponse(200, body: {"roles": {}, "permissions": {}});
      case "GET /api/plugins/":
        return FakeResponse(200, body: []);
    }

    if (user == null) {
      return _unauthenticated();
    }

    // Any other (authenticated) request - echo back the request data
    return FakeResponse(
      request.method == "POST" ? 201 : 200,
      body: {"method": request.method, "path": request.path},
    );
  }

  FakeResponse _unauthenticated() => FakeResponse(
    401,
    body: {"detail": "Authentication credentials were not provided."},
  );
}
