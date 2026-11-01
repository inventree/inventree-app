import "package:inventree/api.dart";

/*
 * Data types for responses from the (allauth headless) authentication API.
 * Ref: https://docs.allauth.org/en/latest/headless/openapi-specification/
 */

// Flow identifiers (as returned by the server in the "flows" list)
const String FLOW_LOGIN = "login";
const String FLOW_MFA_AUTHENTICATE = "mfa_authenticate";
const String FLOW_MFA_TRUST = "mfa_trust";
const String FLOW_MFA_REGISTER = "mfa_register";
const String FLOW_PROVIDER_REDIRECT = "provider_redirect";
const String FLOW_PROVIDER_TOKEN = "provider_token";
const String FLOW_PROVIDER_SIGNUP = "provider_signup";
const String FLOW_VERIFY_EMAIL = "verify_email";

// MFA authenticator types
const String MFA_TYPE_TOTP = "totp";
const String MFA_TYPE_RECOVERY_CODES = "recovery_codes";
const String MFA_TYPE_WEBAUTHN = "webauthn";

// MFA types which the app is able to complete
const List<String> SUPPORTED_MFA_TYPES = [
  MFA_TYPE_TOTP,
  MFA_TYPE_RECOVERY_CODES,
];

enum AuthStatus {
  // User is fully authenticated
  authenticated,
  // Further action is required (see AuthResult.pendingFlow)
  flowPending,
  // Authentication failed (see AuthResult.errors)
  failed,
}

/*
 * An authentication "flow" - e.g. a pending MFA step
 */
class AuthFlow {
  AuthFlow({
    required this.id,
    this.isPending = false,
    this.types = const [],
    this.provider = "",
  });

  factory AuthFlow.fromJson(Map<String, dynamic> json) {
    List<String> types = [];

    if (json["types"] is List) {
      types = (json["types"] as List).map((t) => t.toString()).toList();
    }

    String provider = "";

    if (json["provider"] is Map) {
      provider = ((json["provider"] as Map)["id"] ?? "").toString();
    }

    return AuthFlow(
      id: (json["id"] ?? "").toString(),
      isPending: (json["is_pending"] ?? false) == true,
      types: types,
      provider: provider,
    );
  }

  final String id;
  final bool isPending;

  // Available authenticator types (for MFA flows)
  final List<String> types;

  // Provider ID (for SSO flows)
  final String provider;

  // Can the app complete this MFA flow (i.e. supports at least one of the types)?
  bool get isSupportedMfa =>
      id == FLOW_MFA_AUTHENTICATE &&
      types.any((t) => SUPPORTED_MFA_TYPES.contains(t));

  bool get supportsRecoveryCodes => types.contains(MFA_TYPE_RECOVERY_CODES);

  @override
  String toString() => "AuthFlow(${id}, pending=${isPending}, types=${types})";
}

/*
 * Result of an authentication request
 */
class AuthResult {
  AuthResult({
    required this.status,
    this.statusCode = -1,
    this.pendingFlow,
    this.errors = const [],
    this.user = const {},
  });

  factory AuthResult.failed(String error, {int statusCode = -1}) => AuthResult(
    status: AuthStatus.failed,
    statusCode: statusCode,
    errors: error.isEmpty ? [] : [error],
  );

  /*
   * Construct an AuthResult from an allauth API response
   */
  factory AuthResult.fromResponse(APIResponse response) {
    final int statusCode = response.statusCode;
    final Map<String, dynamic> body = response.asMap();

    final Map<String, dynamic> data = body["data"] is Map<String, dynamic>
        ? body["data"] as Map<String, dynamic>
        : {};

    final Map<String, dynamic> meta = body["meta"] is Map<String, dynamic>
        ? body["meta"] as Map<String, dynamic>
        : {};

    if (statusCode == 200 && meta["is_authenticated"] == true) {
      return AuthResult(
        status: AuthStatus.authenticated,
        statusCode: statusCode,
        user: data["user"] is Map<String, dynamic>
            ? data["user"] as Map<String, dynamic>
            : {},
      );
    }

    if (statusCode == 401 && data["flows"] is List) {
      for (var flow in data["flows"] as List) {
        if (flow is Map<String, dynamic>) {
          final AuthFlow f = AuthFlow.fromJson(flow);

          if (f.isPending) {
            return AuthResult(
              status: AuthStatus.flowPending,
              statusCode: statusCode,
              pendingFlow: f,
            );
          }
        }
      }
    }

    return AuthResult(
      status: AuthStatus.failed,
      statusCode: statusCode,
      errors: extractErrors(body),
    );
  }

  final AuthStatus status;
  final int statusCode;
  final AuthFlow? pendingFlow;
  final List<String> errors;
  final Map<String, dynamic> user;

  bool get authenticated => status == AuthStatus.authenticated;

  String get errorMessage => errors.join("\n");

  @override
  String toString() =>
      "AuthResult(${status.name}, status=${statusCode}, flow=${pendingFlow})";
}

/*
 * Extract human-readable error messages from an allauth (or DRF) error response
 */
List<String> extractErrors(Map<String, dynamic> body) {
  List<String> errors = [];

  if (body["errors"] is List) {
    for (var error in body["errors"] as List) {
      if (error is Map && error["message"] != null) {
        errors.add(error["message"].toString());
      }
    }
  }

  for (final key in ["detail", "error", "message"]) {
    if (errors.isEmpty && body[key] is String) {
      errors.add(body[key] as String);
    }
  }

  return errors;
}

/*
 * A (social) authentication provider configured on the server.
 * Not yet used by the app - provided for future SSO support.
 */
class AuthProvider {
  AuthProvider({
    required this.id,
    required this.name,
    this.flows = const [],
    this.clientId = "",
  });

  factory AuthProvider.fromJson(Map<String, dynamic> json) => AuthProvider(
    id: (json["id"] ?? "").toString(),
    name: (json["name"] ?? "").toString(),
    flows: json["flows"] is List
        ? (json["flows"] as List).map((f) => f.toString()).toList()
        : [],
    clientId: (json["client_id"] ?? "").toString(),
  );

  final String id;
  final String name;
  final List<String> flows;
  final String clientId;

  // Can this provider be used with a native (token based) login?
  bool get supportsTokenLogin => flows.contains(FLOW_PROVIDER_TOKEN);
}

/*
 * Server authentication configuration
 */
class AuthConfig {
  AuthConfig({
    this.loginMethods = const ["username"],
    this.mfaTypes = const [],
    this.providers = const [],
  });

  factory AuthConfig.fromResponse(APIResponse response) {
    final Map<String, dynamic> body = response.asMap();

    if (!response.successful() || body["data"] is! Map<String, dynamic>) {
      return AuthConfig();
    }

    final Map<String, dynamic> data = body["data"] as Map<String, dynamic>;

    final Map<String, dynamic> account = data["account"] is Map<String, dynamic>
        ? data["account"] as Map<String, dynamic>
        : {};

    final Map<String, dynamic> mfa = data["mfa"] is Map<String, dynamic>
        ? data["mfa"] as Map<String, dynamic>
        : {};

    final Map<String, dynamic> social =
        data["socialaccount"] is Map<String, dynamic>
        ? data["socialaccount"] as Map<String, dynamic>
        : {};

    List<String> loginMethods = [];

    if (account["login_methods"] is List) {
      loginMethods = (account["login_methods"] as List)
          .map((m) => m.toString())
          .toList();
    }

    return AuthConfig(
      loginMethods: loginMethods.isEmpty ? ["username"] : loginMethods,
      mfaTypes: mfa["supported_types"] is List
          ? (mfa["supported_types"] as List).map((t) => t.toString()).toList()
          : [],
      providers: social["providers"] is List
          ? (social["providers"] as List)
                .whereType<Map<String, dynamic>>()
                .map((p) => AuthProvider.fromJson(p))
                .toList()
          : [],
    );
  }

  final List<String> loginMethods;
  final List<String> mfaTypes;
  final List<AuthProvider> providers;

  // Which field should the "login" value be sent as?
  String get loginField =>
      (!loginMethods.contains("username") && loginMethods.contains("email"))
      ? "email"
      : "username";
}
