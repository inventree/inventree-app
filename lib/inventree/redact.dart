import "dart:io";

import "package:sentry_flutter/sentry_flutter.dart";

/*
 * Removal of credentials (session cookies, CSRF tokens, API tokens, passwords)
 * from data which leaves the device - e.g. error reports sent to sentry.io.
 *
 * Applied to every Sentry event and breadcrumb (see configureSentryPrivacy),
 * so credentials are removed regardless of where the data was collected.
 */

const String REDACTED = "<redacted>";

// Headers which contain credentials, and must never be logged or reported
const List<String> SENSITIVE_HEADERS = [
  "authorization",
  "cookie",
  "set-cookie",
  "x-csrftoken",
];

// Any map key containing one of these values is treated as a credential
const List<String> _SENSITIVE_KEY_PARTS = [
  "authorization",
  "cookie",
  "csrf",
  "password",
  "passwd",
  "secret",
  "sessionid",
  "token",
  "mfa_trusted",
  "apikey",
  "api_key",
  "api-key",
];

bool isSensitiveKey(String key) {
  final String k = key.toLowerCase();

  return _SENSITIVE_KEY_PARTS.any(k.contains);
}

// Patterns for credentials embedded in free text (log messages, headers, JSON, URLs)
final List<(RegExp, String Function(Match))> _PATTERNS = [
  // Header values: "Cookie: ...", "Authorization: ...", "X-CSRFToken: ..."
  (
    RegExp(
      r"""\b((?:set-)?cookies?|authorization|x-csrftoken)(["']?\s*[:=]\s*["']?)[^\n"']*""",
      caseSensitive: false,
    ),
    (m) => "${m[1]}${m[2]}${REDACTED}",
  ),
  // Session / CSRF cookies: "sessionid=abc"
  (
    RegExp(
      r"\b(sessionid|csrftoken|csrfmiddlewaretoken|mfa_trusted)=[^;,\s&"
      "']+",
      caseSensitive: false,
    ),
    (m) => "${m[1]}=${REDACTED}",
  ),
  // Key / value pairs (JSON, maps, form data): "password": "abc", token=abc
  (
    RegExp(
      r"""(["']?\b(?:password|passwd|secret|token|api[_-]?key|access_token|refresh_token|id_token|csrftoken|csrfmiddlewaretoken|sessionid|mfa_trusted)\b["']?\s*[:=]\s*)(["']?)[^"'\s,;&}\]\n]+""",
      caseSensitive: false,
    ),
    (m) => "${m[1]}${m[2]}${REDACTED}",
  ),
  // Authorization schemes in free text: "Token abc123..."
  (
    RegExp(
      r"\b(Token|Bearer|Basic)\s+(?=[A-Za-z0-9._~+/=-]*\d)[A-Za-z0-9._~+/=-]{8,}",
    ),
    (m) => "${m[1]} ${REDACTED}",
  ),
  // InvenTree API tokens
  (
    RegExp(r"\binv-[0-9a-f]{20,}(?:-\d{8})?\b", caseSensitive: false),
    (m) => REDACTED,
  ),
  // Credentials in a URL: "https://user:password@host"
  (
    RegExp(
      r"\b([a-z][a-z0-9+.-]*://)[^/\s:@]+:[^/\s@]+@",
      caseSensitive: false,
    ),
    (m) => "${m[1]}${REDACTED}@",
  ),
  // Credentials in URL query parameters
  (
    RegExp(
      r"([?&](?:token|access_token|refresh_token|id_token|password|secret|api_?key|key|code|sessionid|csrftoken)=)[^&#\s"
      "']+",
      caseSensitive: false,
    ),
    (m) => "${m[1]}${REDACTED}",
  ),
];

/*
 * Remove any credentials from the provided text
 */
String redactString(String text) {
  for (final (pattern, replace) in _PATTERNS) {
    text = text.replaceAllMapped(pattern, replace);
  }

  return text;
}

/*
 * Remove any credentials from the provided value.
 * Maps and lists are processed recursively - values for sensitive keys
 * are removed entirely, and all strings are scrubbed.
 */
dynamic redactValue(dynamic value) {
  if (value is String) {
    return redactString(value);
  }

  if (value is Map) {
    // Keys are always strings in reported (JSON) data
    return value.map<String, dynamic>(
      (key, v) => MapEntry(
        key.toString(),
        isSensitiveKey(key.toString()) ? REDACTED : redactValue(v),
      ),
    );
  }

  if (value is List) {
    return value.map(redactValue).toList();
  }

  return value;
}

Map<String, String> _redactHeaderMap(Map<String, String> headers) =>
    headers.map(
      (key, value) => MapEntry(
        key,
        SENSITIVE_HEADERS.contains(key.toLowerCase())
            ? REDACTED
            : redactString(value),
      ),
    );

/*
 * Return a string representation of the provided headers,
 * with any credentials removed (e.g. for error reporting)
 */
String redactHeaders(Map<String, String> headers) {
  return _redactHeaderMap(
    headers,
  ).entries.map((entry) => "${entry.key}: ${entry.value}").join("\n");
}

String redactHttpHeaders(HttpHeaders headers) {
  Map<String, String> values = {};

  headers.forEach((name, value) {
    values[name] = value.join(", ");
  });

  return redactHeaders(values);
}

/*
 * Remove credentials from a Sentry breadcrumb (e.g. captured print() output)
 */
Breadcrumb? redactBreadcrumb(Breadcrumb? breadcrumb) {
  if (breadcrumb == null) {
    return null;
  }

  if (breadcrumb.message != null) {
    breadcrumb.message = redactString(breadcrumb.message!);
  }

  if (breadcrumb.data != null) {
    breadcrumb.data = redactValue(breadcrumb.data) as Map<String, dynamic>;
  }

  return breadcrumb;
}

/*
 * Remove credentials from a Sentry event, before it is sent
 */
SentryEvent redactSentryEvent(SentryEvent event) {
  final SentryMessage? message = event.message;

  if (message != null) {
    message.formatted = redactString(message.formatted);

    if (message.template != null) {
      message.template = redactString(message.template!);
    }

    if (message.params != null) {
      message.params = redactValue(message.params) as List<dynamic>;
    }
  }

  // Chained exceptions are flattened into this list by the SDK
  for (final exception in event.exceptions ?? <SentryException>[]) {
    if (exception.value != null) {
      exception.value = redactString(exception.value!);
    }
  }

  if (event.tags != null) {
    event.tags = event.tags!.map(
      (key, value) =>
          MapEntry(key, isSensitiveKey(key) ? REDACTED : redactString(value)),
    );
  }

  // Deprecated by Sentry (not used by the app) - but still sent if present
  // ignore: deprecated_member_use
  if (event.extra != null) {
    // ignore: deprecated_member_use
    event.extra = redactValue(event.extra) as Map<String, dynamic>;
  }

  // Context data provided by the app (SDK-provided contexts are typed objects)
  for (final key in event.contexts.keys.toList()) {
    final dynamic value = event.contexts[key];

    if (value is String || value is Map || value is List) {
      event.contexts[key] = isSensitiveKey(key) ? REDACTED : redactValue(value);
    }
  }

  event.breadcrumbs = event.breadcrumbs
      ?.map(redactBreadcrumb)
      .whereType<Breadcrumb>()
      .toList();

  final SentryRequest? request = event.request;

  if (request != null) {
    event.request = SentryRequest(
      url: request.url == null ? null : redactString(request.url!),
      method: request.method,
      queryString: request.queryString == null
          ? null
          : redactString("?${request.queryString!}").substring(1),
      cookies: request.cookies == null ? null : REDACTED,
      fragment: request.fragment,
      apiTarget: request.apiTarget,
      data: redactValue(request.data),
      headers: _redactHeaderMap(request.headers),
      env: request.env,
    );
  }

  return event;
}

/*
 * Configure Sentry so that credentials (and other personal information)
 * are never sent with error reports.
 *
 * If redaction fails, Sentry would send the original (unredacted) data -
 * so the event or breadcrumb is dropped instead (fail closed).
 */
void configureSentryPrivacy(SentryOptions options) {
  options.sendDefaultPii = false;
  options.maxRequestBodySize = MaxRequestBodySize.never;

  options.beforeSend = (event, hint) {
    try {
      return redactSentryEvent(event);
    } catch (error) {
      print("Error redacting Sentry event - event dropped: ${error}");
      return null;
    }
  };

  options.beforeBreadcrumb = (breadcrumb, hint) {
    try {
      return redactBreadcrumb(breadcrumb);
    } catch (error) {
      return null;
    }
  };
}
