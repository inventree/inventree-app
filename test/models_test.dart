/*
 * Unit tests for accessing various model classes via the API
 */

import 'package:inventree/inventree/model.dart';
import "package:test/test.dart";

import "package:inventree/api.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/inventree/part.dart";


void main() {

  setUp(() async {
    await UserProfileDBManager().addProfile(UserProfile(
      name: "Test Profile",
      server: "http://localhost:12345",
      username: "testuser",
      password: "testpassword",
      selected: true,
    ));

    assert(await UserProfileDBManager().selectProfileByName("Test Profile"));
    assert(await InvenTreeAPI().connectToServer());
  });

  group("Part Tests:", () {

    test("List Parts", () async {
      List<InvenTreeModel> results;

      // List *all* parts
      results = await InvenTreePart().list();
      assert(results.length == 13);

      for (var result in results) {
        // results must be InvenTreePart instances
        assert(result is InvenTreePart);
      }

      // Filter by category
      results = await InvenTreePart().list(
        filters: {
          "category": "2",
        }
      );

      assert(results.length == 2);
    });

  });

}