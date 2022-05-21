/*
 * Unit tests for the InvenTree API code
 */

import "package:test/test.dart";

import "package:inventree/api.dart";
import "package:inventree/user_profile.dart";



void main() {
  
  setUp(() async {
    
    // Create and select a profile to user
    await UserProfileDBManager().addProfile(UserProfile(
      name: "Test Profile",
      server: "http://localhost:12345",
      username: "testuser",
      password: "testpassword",
      selected: true,
    ));

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
      }

      bool result = await api.connectToServer();

      assert(!result);

      // TODO: Test the the right 'error message' is returned

      // TODO: Test incorrect login details

    });

    test("Login Success", () async {
      // Test that we can login to the server successfully
      var api = InvenTreeAPI();

      // Attempt to connect
      final bool result = await api.connectToServer();

      // Check expected values
      expect(result, equals(true));
      expect(api.hasToken, equals(true));
      expect(api.baseUrl, equals("http://localhost:12345/"));

      expect(api.isConnected(), equals(true));
      expect(api.isConnecting(), equals(false));
    });
  });
}