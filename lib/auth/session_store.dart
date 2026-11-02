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
 * Return the origin (scheme, host and port) of the provided server address,
 * or an empty string if the address is not valid.
 * Default ports are included, so "https://host" and "https://host:443" match.
 */
String serverOrigin(String server) {
  final Uri? uri = Uri.tryParse(server);

  if (uri == null || uri.host.isEmpty || uri.scheme.isEmpty) {
    return "";
  }

  return "${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}:${uri.port}";
}

/*
 * Cookie jar for the session with a single InvenTree server.
 *
 * Cookies are only accepted from (and sent to) the server origin,
 * so that session credentials can never leak to another host.
 * The jar can be serialized for storage in secure storage, and records the
 * origin which issued the cookies - a stored jar is only ever restored for
 * that same origin.
 */
class SessionStore {
  SessionStore({String server = ""}) {
    _serverUri = Uri.tryParse(server);
  }

  /*
   * Restore a stored jar for the provided server.
   *
   * The cookies are discarded (and [rejected] is set) if they were issued by
   * a different origin - e.g. the profile server address has since been edited
   * (by the user, or by managed configuration). Otherwise the session could be
   * sent to a different service on the same host, or over plain HTTP.
   */
  factory SessionStore.fromJson(String server, String? data) {
    final store = SessionStore(server: server);

    if (data == null || data.isEmpty) {
      return store;
    }

    try {
      final dynamic decoded = json.decode(data);

      // Data stored without an origin cannot be verified (and is never restored)
      final String origin = decoded is Map<String, dynamic>
          ? (decoded["origin"] ?? "").toString()
          : "";

      if (origin.isEmpty || origin != store.origin) {
        store.rejected = true;
        return store;
      }

      final List<dynamic> cookies = decoded["cookies"] as List<dynamic>;

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

    // These cookies are already stored
    store._persisted = Map.of(store._cookies);

    return store;
  }

  Uri? _serverUri;

  // Origin of the server this jar belongs to
  String get origin => serverOrigin(_serverUri?.toString() ?? "");

  // Set if stored cookies were discarded, as they were issued by a different origin
  bool rejected = false;

  final Map<String, StoredCookie> _cookies = {};

  // Cookies as last written to storage (see markPersisted)
  Map<String, StoredCookie> _persisted = {};

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

    // Deleted (or expired) by the server
    if (cookie.value.isEmpty ||
        (expires != null && !expires.isAfter(DateTime.now()))) {
      final bool removed = _cookies.remove(cookie.name) != null;

      return removed || _persisted.containsKey(cookie.name);
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

    return _differsFromPersisted(stored);
  }

  /*
   * Return true if the cookie differs meaningfully from the copy last persisted.
   *
   * Compared against the persisted copy (not the previous in-memory value),
   * so that small changes accumulate - e.g. a sliding expiry which is extended
   * slightly on each request is persisted once it has moved by an hour.
   * Expiry changes of less than an hour are ignored, to avoid re-writing
   * secure storage on every request.
   */
  bool _differsFromPersisted(StoredCookie cookie) {
    final StoredCookie? persisted = _persisted[cookie.name];

    if (persisted == null ||
        persisted.value != cookie.value ||
        persisted.domain != cookie.domain ||
        persisted.hostOnly != cookie.hostOnly ||
        persisted.path != cookie.path ||
        persisted.secure != cookie.secure) {
      return true;
    }

    final DateTime? a = persisted.expires;
    final DateTime? b = cookie.expires;

    if ((a == null) != (b == null)) return true;

    return a != null && b != null && a.difference(b).abs().inHours >= 1;
  }

  /*
   * Return a copy of the current cookies, to pass to markPersisted()
   * once they have been written to storage
   */
  Map<String, StoredCookie> snapshot() => Map.of(_cookies);

  /*
   * Record the cookies which have been written to storage.
   * Only called once the write succeeds - so after a failed write, the next
   * change is reported again (and the write retried)
   */
  void markPersisted(Map<String, StoredCookie> snapshot) {
    _persisted = Map.of(snapshot);
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

  String toJson() => json.encode({
    "origin": origin,
    "cookies": _cookies.values
        .where((cookie) => !cookie.isExpired)
        .map((cookie) => cookie.toJson())
        .toList(),
  });
}
