/*
 * Unit tests for the API class
 */

import "package:test/test.dart";
import "package:inventree/user_profile.dart";

void main() {

  setUp(() async {
    // Ensure we have a user profile available
    // This profile will match the dockerized InvenTree setup, running locally
    await UserProfileDBManager().addProfile(UserProfile(
      username: "testuser",
      password: "testpassword""",
      server: "http://localhost:12345",
      selected: true,
    ));

    final profiles = await UserProfileDBManager().getAllProfiles();

    // Ensure we have one profile available
    expect(profiles.length, equals(1));

    // Select the profile
    await UserProfileDBManager().selectProfile(profiles.first.key ?? 1);

  });

  // Run a set of tests for user profile functionality
  group("Profile Tests", () async {

    test("Profile Name Check", () async {
      bool result = false;

      result = await UserProfileDBManager().profileNameExists("doesnotexist");
      expect(result, equals(false));

      result = await UserProfileDBManager().profileNameExists("testuser");
      expect(result, equals(true));
    });

    // Ensure that we can select a user profile
    test("Select Profile", () async {
      final prf = await UserProfileDBManager().getSelectedProfile();

      expect(prf, isNot(null));

      expect(prf?.username, equals("testuser"));
      expect(prf?.password, equals("testpassword"));
      expect(prf?.server, equals("http://localhost:12345"));
    });
  });

}