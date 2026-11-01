import "package:inventree/auth/allauth_client.dart";
import "package:inventree/auth/auth_result.dart";

/*
 * A method for starting a login against the server.
 *
 * Each method only performs the *initial* authentication step -
 * any subsequent flows (e.g. MFA) are handled by InvenTreeAuth,
 * regardless of how the login was started.
 *
 * Future SSO support adds a ProviderAuthMethod which obtains a token
 * from the provider and calls AllauthClient.loginProviderToken()
 */
abstract class AuthMethod {
  const AuthMethod();

  // Username to remember against the profile once login succeeds (if any)
  String get username => "";

  Future<AuthResult> authenticate(AllauthClient client, AuthConfig config);
}

/*
 * Login with username (or email) and password
 */
class PasswordAuthMethod extends AuthMethod {
  const PasswordAuthMethod(this.login, this.password);

  final String login;
  final String password;

  @override
  String get username => login;

  @override
  Future<AuthResult> authenticate(AllauthClient client, AuthConfig config) {
    return client.loginPassword(
      login: login,
      password: password,
      field: config.loginField,
    );
  }
}
