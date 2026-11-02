/*
 * Unit tests for the InvenTree API code
 */

import "dart:io";

import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/auth/session_store.dart";
import "package:inventree/helpers.dart";
import "package:inventree/user_profile.dart";

import "setup.dart";

void main() {
  setupTestEnv();

  setUp(() async {
    await setupServerProfile(select: true);

    // Ensure the profile is selected
    assert(
      !await UserProfileDBManager().selectProfileByName("Missing Profile"),
    );
    assert(await UserProfileDBManager().selectProfileByName(testServerName));
  });

  // Ensure that generated URLs are correct
  group("URL Tests:", () {
    test("Generate URLs", () async {
      UserProfile profile = await setupServerProfile();
      var api = InvenTreeAPI();

      api.profile = profile;

      Map<String, String> tests = {
        "": "http://localhost:8000/api/",
        "barcode/": "http://localhost:8000/api/barcode/",
        "https://remote-server.com/media/image.png":
            "https://remote-server.com/media/image.png",
      };

      for (var test in tests.entries) {
        expect(api.makeApiUrl(test.key), equals(test.value));
      }
    });
  });

  group("Login Tests:", () {
    test("Disconnected", () async {
      // Test that calling disconnect() does the right thing
      var api = InvenTreeAPI();

      api.disconnectFromServer();

      // Check expected values
      expect(api.isConnected(), equals(false));
      expect(api.isConnecting(), equals(false));
      expect(api.hasSession, equals(false));
    });

    test("Login Failure", () async {
      // Tests for various types of login failures
      var api = InvenTreeAPI();

      // Incorrect server address
      var profile = await setupServerProfile();

      profile.server = "http://localhost:5555";

      bool result = await api.connectToServer(profile);
      assert(!result);

      debugContains("SocketException at");

      // Test incorrect login details
      profile.server = testServerAddress;

      final authResult = await InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod("baduser", "badpassword"),
      );
      assert(!authResult.authenticated);
      assert(authResult.errors.isNotEmpty);

      assert(!api.checkConnection());

      debugContains("InvenTreeAuth: AuthResult(failed, status=400");
      debugContains("showSnackIcon: 'Not Connected'");
    });

    test("Bad Session", () async {
      // Test that connection fails with an invalid session cookie
      var profile = await setupServerProfile();

      final session = SessionStore(server: profile.server);

      session.capture(Uri.parse(profile.server), [
        Cookie(SESSION_COOKIE_NAME, "bad-session"),
      ]);

      await UserProfileDBManager().saveSession(profile, session);

      bool result = await InvenTreeAPI().connectToServer(profile);
      assert(!result);

      // The invalid session should have been discarded
      final stored = await UserProfileDBManager().loadSession(profile);
      assert(!stored.hasSession);
    });

    test("Login Success", () async {
      // Test that we can login to the server successfully
      var api = InvenTreeAPI();

      final profile = await setupServerProfile(select: true, login: true);
      assert(profile.hasSession);

      // Now, connect to the server
      bool result = await api.connectToServer(profile);

      // Check expected values
      assert(result);
      assert(api.hasSession);

      expect(api.baseUrl, equals(testServerAddress));

      assert(api.hasSession);
      assert(api.isConnected());
      assert(!api.isConnecting());
      assert(api.checkConnection());
    });

    test("Version Checks", () async {
      // Test server version information
      var api = InvenTreeAPI();

      final profile = await setupServerProfile(login: true);
      assert(await api.connectToServer(profile));

      // Check supported functions
      assert(api.apiVersion >= 50);
      assert(api.serverInstance.isNotEmpty);
      assert(api.serverVersion.isNotEmpty);

      // Ensure we can have user role data
      assert(api.roles.isNotEmpty);

      // Check available permissions
      assert(api.checkRole("part", "change"));
      assert(api.checkRole("stock", "delete"));
      assert(!api.checkRole("part", "weirdpermission"));
      assert(api.checkRole("blah", "bloo"));

      // Pricing role (or legacy server with no pricing role)
      assert(api.canViewPricing);

      debugContains("showSnackIcon: 'Connected to Server'");
    });
  });
}
