/*
 * Unit tests for the InvenTree API code
 */

import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/user_profile.dart";

import "setup.dart";



void main() {
  setupTestEnv();

  setUp(() async {

    if (! await UserProfileDBManager().profileNameExists("Test Profile")) {
      // Create and select a profile to user

      print("TEST: Creating profile for user 'testuser'");

      await UserProfileDBManager().addProfile(UserProfile(
        name: "Test Profile",
        server: "http://localhost:12345",
        username: "testuser",
        password: "testpassword",
        selected: true,
      ));
    }

    var prf = await UserProfileDBManager().getSelectedProfile();

    // Ensure that the server settings are correct by default,
    // as they can get overwritten by subsequent tests

    if (prf != null) {
      prf.name = "Test Profile";
      prf.server = "http://localhost:12345";
      prf.username = "testuser";
      prf.password = "testpassword";

      await UserProfileDBManager().updateProfile(prf);
    }

    // Ensure the profile is selected
    assert(! await UserProfileDBManager().selectProfileByName("Missing Profile"));
    assert(await UserProfileDBManager().selectProfileByName("Test Profile"));

  });

  group("Login Tests:", () {

    test("Disconnected", () async {
      // Test that calling disconnect() does the right thing
      var api = InvenTreeAPI();

      api.disconnectFromServer();

      // Check expected values
      expect(api.isConnected(), equals(false));
      expect(api.isConnecting(), equals(false));
      expect(api.hasToken, equals(false));

    });

    test("Login Failure", () async {
      // Tests for various types of login failures
      var api = InvenTreeAPI();

      // Incorrect server address
      var profile = await UserProfileDBManager().getSelectedProfile();

      assert(profile != null);

      if (profile != null) {
        profile.server = "http://localhost:5555";
        await UserProfileDBManager().updateProfile(profile);

        bool result = await api.connectToServer();
        assert(!result);

        debugContains("SocketException at");

        // Test incorrect login details
        profile.server = "http://localhost:12345";
        profile.username = "invalidusername";

        await UserProfileDBManager().updateProfile(profile);

        await api.connectToServer();
        assert(!result);

        debugContains("Token request failed");

        assert(!api.checkConnection());

        debugContains("Token request failed: STATUS 401");
        debugContains("showSnackIcon: 'Not Connected'");

      } else {
        assert(false);
      }

    });

    test("Login Success", () async {
      // Test that we can login to the server successfully
      var api = InvenTreeAPI();

      // Attempt to connect
      final bool result = await api.connectToServer();

      // Check expected values
      assert(result);
      assert(api.hasToken);
      expect(api.baseUrl, equals("http://localhost:12345/"));

      assert(api.isConnected());
      assert(!api.isConnecting());
      assert(api.checkConnection());
    });

    test("Version Checks", () async {
      // Test server version information
      var api = InvenTreeAPI();

      assert(await api.connectToServer());

      // Check supported functions
      assert(api.apiVersion >= 50);
      assert(api.supportsSettings);
      assert(api.supportsNotifications);
      assert(api.supportsPoReceive);

      // Ensure we can request (and receive) user roles
      assert(await api.getUserRoles());

      // Check available permissions
      assert(api.checkPermission("part", "change"));
      assert(api.checkPermission("stocklocation", "delete"));
      assert(!api.checkPermission("part", "weirdpermission"));
      assert(api.checkPermission("blah", "bloo"));

      debugContains("Received token from server");
      debugContains("showSnackIcon: 'Connected to Server'");
    });

  });
}