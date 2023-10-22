
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:inventree/api.dart";
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

  // Mock the path provider
  const MethodChannel channel = MethodChannel("plugins.flutter.io/path_provider");
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return ".";
  });
}

// Accessors for default testing values
const String testServerAddress = "http://localhost:8000";
const String testServerName = "Test Server";
const String testUsername = "allaccess";
const String testPassword = "nolimits";


Future<bool> fetchProfileToken({
  UserProfile? profile,
  String username = testUsername,
  String password = testPassword
}) async {

  if (profile == null) {
    profile = await UserProfileDBManager().getProfileByName(testServerName);
  }

  assert(profile != null);

  bool result = await InvenTreeAPI().fetchToken(profile!, username, password);
  return result;
}


/*
 * Setup a valid profile, and return it
 */
Future<UserProfile> setupServerProfile({bool select = true, bool fetchToken = false}) async {
  // Setup a valid server profile

  UserProfile? profile = await UserProfileDBManager().getProfileByName(testServerName);

  if (profile == null) {
    // Profile does not already exist - create it!
    bool result = await UserProfileDBManager().addProfile(
        UserProfile(
          server: testServerAddress,
          name: testServerName
        )
    );

    assert(result);
  }

  profile = await UserProfileDBManager().getProfileByName(testServerName);
  assert(profile != null);

  if (select) {
    assert(await UserProfileDBManager().selectProfileByName(testServerName));
  }

  if (fetchToken) {
    final bool result = await fetchProfileToken(profile: profile);
    assert(result);
    assert(profile!.hasToken);
  }

  return profile!;
}