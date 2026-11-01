import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:inventree/api.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/user_profile.dart";

// This is the same as the following issue except it keeps the http client
// TestWidgetsFlutterBinding.ensureInitialized();
class CustomBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void setupTestEnv() {
  // Uses custom binding to not override the http client
  CustomBinding();

  // Package information is used when building error reports
  PackageInfo.setMockInitialValues(
    appName: "InvenTree",
    packageName: "inventree.inventree_app",
    version: "0.0.0",
    buildNumber: "0",
    buildSignature: "",
  );

  // Mock the path provider
  const MethodChannel channel = MethodChannel(
    "plugins.flutter.io/path_provider",
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return ".";
      });

  // Mock secure storage (used for storing profile session cookies) with a
  // simple in-memory map, since there's no real platform keychain available
  // in the test harness
  final Map<String, String> secureStorageMock = {};
  const MethodChannel secureStorageChannel = MethodChannel(
    "plugins.it_nomads.com/flutter_secure_storage",
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        final Map<dynamic, dynamic> args =
            (methodCall.arguments as Map<dynamic, dynamic>?) ?? {};
        final String? key = args["key"] as String?;

        switch (methodCall.method) {
          case "write":
            secureStorageMock[key!] = args["value"] as String;
            return null;
          case "read":
            return secureStorageMock[key];
          case "containsKey":
            return secureStorageMock.containsKey(key);
          case "delete":
            secureStorageMock.remove(key);
            return null;
          case "deleteAll":
            secureStorageMock.clear();
            return null;
          case "readAll":
            return secureStorageMock;
          default:
            return null;
        }
      });
}

// Accessors for default testing values
const String testServerAddress = "http://localhost:8000/";
const String testServerName = "Test Server";
const String testUsername = "admin";
const String testPassword = "inventree";

/*
 * Login to the server with the given profile (establishing a session)
 */
Future<bool> loginProfile({
  UserProfile? profile,
  String username = testUsername,
  String password = testPassword,
}) async {
  profile ??= await UserProfileDBManager().getProfileByName(testServerName);

  assert(profile != null);

  final result = await InvenTreeAuth().beginLogin(
    profile!,
    PasswordAuthMethod(username, password),
  );

  return result.authenticated;
}

/*
 * Setup a valid profile, and return it
 */
Future<UserProfile> setupServerProfile({
  bool select = true,
  bool login = false,
}) async {
  // Setup a valid server profile

  UserProfile? profile = await UserProfileDBManager().getProfileByName(
    testServerName,
  );

  if (profile == null) {
    // Profile does not already exist - create it!
    bool result = await UserProfileDBManager().addProfile(
      UserProfile(server: testServerAddress, name: testServerName),
    );

    assert(result);
  }

  profile = await UserProfileDBManager().getProfileByName(testServerName);
  assert(profile != null);

  if (select) {
    assert(await UserProfileDBManager().selectProfileByName(testServerName));
  }

  if (login && !profile!.hasSession) {
    final bool result = await loginProfile(profile: profile);
    assert(result);
    assert(profile.hasSession);
  }

  return profile!;
}

/*
 * Complete all steps necessary to login to the server
 */
Future<void> connectToTestServer() async {
  // Setup profile, and login as necessary
  final profile = await setupServerProfile(login: true);

  // Connect to the server
  assert(await InvenTreeAPI().connectToServer(profile));
}
