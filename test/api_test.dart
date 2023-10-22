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

    await setupServerProfile(select: true);

    // Ensure the profile is selected
    assert(! await UserProfileDBManager().selectProfileByName("Missing Profile"));
    assert(await UserProfileDBManager().selectProfileByName(testServerName));

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
      var profile = await setupServerProfile();

      profile.server = "http://localhost:5555";

      bool result = await api.connectToServer(profile);
      assert(!result);

      debugContains("SocketException at");

      // Test incorrect login details
      profile.server = testServerAddress;

      final response = await api.fetchToken(profile, "baduser", "badpassword");
      assert(!response.successful());

      debugContains("Token request failed");

      assert(!api.checkConnection());

      debugContains("Token request failed: STATUS 401");
      debugContains("showSnackIcon: 'Not Connected'");

    });

    test("Bad Token", () async {
      // Test that login fails with a bad token
      var profile = await setupServerProfile();

      profile.token = "bad-token";

      bool result = await InvenTreeAPI().connectToServer(profile);
      assert(!result);
    });

    test("Login Success", () async {
      // Test that we can login to the server successfully
      var api = InvenTreeAPI();

      final profile = await setupServerProfile(select: true, fetchToken: true);
      assert(profile.hasToken);

      // Now, connect to the server
      bool result = await api.connectToServer(profile);

      // Check expected values
      assert(result);
      assert(api.hasToken);

      expect(api.baseUrl, equals(testServerAddress));

      assert(api.hasToken);
      assert(api.isConnected());
      assert(!api.isConnecting());
      assert(api.checkConnection());
    });

    test("Version Checks", () async {
      // Test server version information
      var api = InvenTreeAPI();

      final profile = await setupServerProfile(fetchToken: true);
      assert(await api.connectToServer(profile));

      // Check supported functions
      assert(api.apiVersion >= 50);
      assert(api.supportsSettings);
      assert(api.supportsNotifications);
      assert(api.supportsPoReceive);

      assert(api.serverInstance.isNotEmpty);
      assert(api.serverVersion.isNotEmpty);

      // Ensure we can have user role data
      assert(api.roles.isNotEmpty);

      // Check available permissions
      assert(api.checkPermission("part", "change"));
      assert(api.checkPermission("stock_location", "delete"));
      assert(!api.checkPermission("part", "weirdpermission"));
      assert(api.checkPermission("blah", "bloo"));

      debugContains("Received token from server");
      debugContains("showSnackIcon: 'Connected to Server'");
    });

  });
}