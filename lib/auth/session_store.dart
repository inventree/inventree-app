import "dart:convert";
import "dart:io";

// Default Django cookie names (InvenTree does not override these)
const String SESSION_COOKIE_NAME = "sessionid";
const String CSRF_COOKIE_NAME = "csrftoken";

/*
 * A single cookie, as received from the server.
 */
class StoredCookie {
  StoredCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.hostOnly = true,
    this.path = "/",
    this.expires,
    this.secure = false,
  });

  factory StoredCookie.fromJson(Map<String, dynamic> json) => StoredCookie(
    name: (json["name"] ?? "") as String,
    value: (json["value"] ?? "") as String,
    domain: (json["domain"] ?? "") as String,
    hostOnly: (json["hostOnly"] ?? true) as bool,
    path: (json["path"] ?? "/") as String,
    expires: json["expires"] == null
        ? null
        : DateTime.tryParse(json["expires"] as String),
    secure: (json["secure"] ?? false) as bool,
  );

  final String name;
  final String value;

  // Host (hostOnly) or domain (and subdomains) the cookie applies to
  final String domain;
  final bool hostOnly;

  final String path;

  // Expiry time - null for a "session" cookie (kept until cleared)
  final DateTime? expires;

  // Only send over HTTPS
  final bool secure;

  bool get isExpired => expires != null && expires!.isBefore(DateTime.now());

  // Does this cookie apply to the provided URI?
  bool matches(Uri uri) {
    if (isExpired) return false;

    if (secure && uri.scheme != "https") return false;

    if (!domainMatches(uri.host, domain, hostOnly: hostOnly)) return false;

    String requestPath = uri.path.isEmpty ? "/" : uri.path;

    if (path == "/" || requestPath == path) return true;

    final String prefix = path.endsWith("/") ? path : "${path}/";

    return requestPath.startsWith(prefix);
  }

  Map<String, dynamic> toJson() => {
    "name": name,
    "value": value,
    "domain": domain,
    "hostOnly": hostOnly,
    "path": path,
    "expires": expires?.toIso8601String(),
    "secure": secure,
  };
}

/*
 * Return true if the request host matches the cookie domain (RFC 6265 5.1.3)
 */
bool domainMatches(String host, String domain, {bool hostOnly = false}) {
  host = host.toLowerCase();
  domain = domain.toLowerCase();

  if (host == domain) return true;

  if (hostOnly) return false;

  // Never domain-match an IP address
  if (InternetAddress.tryParse(host) != null) return false;

  return host.endsWith(".${domain}");
}

/*
 * Split a folded "Set-Cookie" header (as returned by package:http,
 * which joins multiple headers with a comma) into individual values.
 * Commas also appear inside "Expires" dates, so only split where the
 * comma is followed by a new "name=" pair.
 */
List<String> splitSetCookieHeader(String header) {
  return header
      .split(RegExp(r",(?=\s*[^;,=\s]+=)"))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

/*
 * Cookie jar for the session with a single InvenTree server.
 *
 * Cookies are only accepted from (and sent to) the server host,
 * so that session credentials can never leak to another host.
 * The jar can be serialized for storage in secure storage.
 */
class SessionStore {
  SessionStore({String server = ""}) {
    _serverUri = Uri.tryParse(server);
  }

  factory SessionStore.fromJson(String server, String? data) {
    final store = SessionStore(server: server);

    if (data == null || data.isEmpty) {
      return store;
    }

    try {
      final List<dynamic> cookies = json.decode(data) as List<dynamic>;

      for (var item in cookies) {
        final cookie = StoredCookie.fromJson(item as Map<String, dynamic>);

        if (cookie.name.isNotEmpty && !cookie.isExpired) {
          store._cookies[cookie.name] = cookie;
        }
      }
    } catch (error) {
      // Corrupt data - start with an empty jar
      store._cookies.clear();
    }

    return store;
  }

  Uri? _serverUri;

  final Map<String, StoredCookie> _cookies = {};

  // Callback when the contents of the jar change (e.g. to persist it)
  void Function()? onChanged;

  void _changed() => onChanged?.call();

  // Names of all (non-expired) cookies - for debugging, never log values!
  List<String> get cookieNames => _cookies.values
      .where((cookie) => !cookie.isExpired)
      .map((cookie) => cookie.name)
      .toList();

  String _value(String name) {
    final StoredCookie? cookie = _cookies[name];

    if (cookie == null || cookie.isExpired) return "";

    return cookie.value;
  }

  String get csrfToken => _value(CSRF_COOKIE_NAME);

  bool get hasCsrfToken => csrfToken.isNotEmpty;

  // Do we have a session cookie (which may or may not still be valid on the server)?
  bool get hasSession => _value(SESSION_COOKIE_NAME).isNotEmpty;

  bool get isEmpty => cookieNames.isEmpty;

  /*
   * Return true if the provided URI points at the server this jar belongs to.
   * Credentials (cookies / CSRF token) must only ever be sent to this host.
   */
  bool isServerUri(Uri uri) {
    final Uri? server = _serverUri;

    if (server == null || server.host.isEmpty) return false;

    return uri.host.toLowerCase() == server.host.toLowerCase() &&
        uri.scheme == server.scheme &&
        uri.port == server.port;
  }

  /*
   * Store cookies received from the server in response to a request to [uri]
   */
  void capture(Uri uri, List<Cookie> cookies) {
    if (cookies.isEmpty || !isServerUri(uri)) return;

    bool changed = false;

    for (final cookie in cookies) {
      if (_store(uri, cookie)) changed = true;
    }

    if (changed) _changed();
  }

  /*
   * Store cookies from raw "Set-Cookie" header values.
   * Each value is parsed individually, so one malformed cookie
   * does not prevent the others from being stored.
   */
  void captureHeaders(Uri uri, List<String>? setCookieHeaders) {
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) return;

    List<Cookie> cookies = [];

    for (final header in setCookieHeaders) {
      try {
        cookies.add(Cookie.fromSetCookieValue(header));
      } catch (error) {
        // Ignore malformed cookie
      }
    }

    capture(uri, cookies);
  }

  // Store a single cookie, returning true if the jar changed
  bool _store(Uri uri, Cookie cookie) {
    String domain = uri.host;
    bool hostOnly = true;

    if (cookie.domain != null && cookie.domain!.isNotEmpty) {
      String d = cookie.domain!.toLowerCase();

      if (d.startsWith(".")) d = d.substring(1);

      // Reject cookies for a domain the server does not belong to
      if (!domainMatches(uri.host, d)) return false;

      domain = d;
      hostOnly = false;
    }

    DateTime? expires = cookie.expires;

    // Max-Age takes precedence over Expires
    if (cookie.maxAge != null) {
      expires = DateTime.now().add(Duration(seconds: cookie.maxAge!));
    }

    final StoredCookie? existing = _cookies[cookie.name];

    // Deleted (or expired) by the server
    if (cookie.value.isEmpty ||
        (expires != null && !expires.isAfter(DateTime.now()))) {
      return _cookies.remove(cookie.name) != null;
    }

    final stored = StoredCookie(
      name: cookie.name,
      value: cookie.value,
      domain: domain,
      hostOnly: hostOnly,
      path: (cookie.path == null || cookie.path!.isEmpty) ? "/" : cookie.path!,
      expires: expires,
      secure: cookie.secure,
    );

    _cookies[cookie.name] = stored;

    // Only report a change when something meaningful changed,
    // to avoid re-writing secure storage on every request
    if (existing == null || existing.value != stored.value) return true;

    final DateTime? a = existing.expires;
    final DateTime? b = stored.expires;

    if ((a == null) != (b == null)) return true;

    return a != null && b != null && a.difference(b).abs().inHours >= 1;
  }

  /*
   * Construct the "Cookie" header value for a request to [uri]
   * Returns an empty string if no cookies apply (or for a foreign host)
   */
  String cookieHeader(Uri uri) {
    if (!isServerUri(uri)) return "";

    return _cookies.values
        .where((cookie) => cookie.matches(uri))
        .map((cookie) => "${cookie.name}=${cookie.value}")
        .join("; ");
  }

  /*
   * Remove the session and CSRF cookies, but retain any others
   * (e.g. the MFA "trusted device" cookie)
   */
  void clearAuthCookies() {
    final bool removedSession = _cookies.remove(SESSION_COOKIE_NAME) != null;
    final bool removedCsrf = _cookies.remove(CSRF_COOKIE_NAME) != null;

    if (removedSession || removedCsrf) _changed();
  }

  // Remove all cookies
  void clear() {
    if (_cookies.isEmpty) return;

    _cookies.clear();
    _changed();
  }

  String toJson() => json.encode(
    _cookies.values
        .where((cookie) => !cookie.isExpired)
        .map((cookie) => cookie.toJson())
        .toList(),
  );
}
