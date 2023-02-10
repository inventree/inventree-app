/*
 * Unit tests for accessing various model classes via the API
 */

import "package:test/test.dart";

import "package:inventree/api.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";

import "setup.dart";


void main() {
  setupTestEnv();

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

  group("Category Tests:", () {
    test("Basics", () async {
      assert(InvenTreePartCategory().URL == "part/category/");
    });

    test("List Categories", () async {
      List<InvenTreeModel> results;

      // List *all* categories
      results = await InvenTreePartCategory().list();
      assert(results.length == 8);

      for (var result in results) {
        assert(result is InvenTreePartCategory);
      }

      // Filter by parent category
      results = await InvenTreePartCategory().list(
        filters: {
          "parent": "1",
        }
      );

      assert(results.length == 3);
    });
  });

  group("Part Tests:", () {

    test("Basics", () async {
      assert(InvenTreePart().URL == "part/");
    });

    test("List Parts", () async {
      List<InvenTreeModel> results;

      // List *all* parts
      results = await InvenTreePart().list();
      expect(results.length, equals(14));

      // List with active filter
      results = await InvenTreePart().list(filters: {"active": "true"});
      expect(results.length, equals(13));

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

    test("Part Detail", () async {
      final result = await InvenTreePart().get(1);

      assert(result != null);
      assert(result is InvenTreePart);

      if (result != null) {
        InvenTreePart part = result as InvenTreePart;

        // Check some basic properties of the part
        assert(part.name == "M2x4 LPHS");
        assert(part.fullname == "M2x4 LPHS");
        assert(part.description == "M2x4 low profile head screw");
        assert(part.categoryId == 8);
        assert(part.categoryName == "Fasteners");
        assert(part.image == part.thumbnail);
        assert(part.thumbnail == "/static/img/blank_image.thumbnail.png");

        // Stock information
        assert(part.unallocatedStockString == "9000");
        assert(part.inStockString == "9000");
      }

    });

    test("Part Adjust", () async {
      // Test that we can update part data
      final result = await InvenTreePart().get(1);

      assert(result != null);
      assert(result is InvenTreePart);

      APIResponse? response;

      if (result != null) {
        InvenTreePart part = result as InvenTreePart;
        assert(part.name == "M2x4 LPHS");

        // Change the name to something else

        response = await part.update(
          values: {
            "name": "Woogle",
          }
        );

        assert(response.isValid());
        assert(response.statusCode == 200);

        assert(await part.reload());
        assert(part.name == "Woogle");

        // And change it back again
        response = await part.update(
          values: {
            "name": "M2x4 LPHS"
          }
        );

        assert(response.isValid());
        assert(response.statusCode == 200);

        assert(await part.reload());
        assert(part.name == "M2x4 LPHS");
      }
    });
  });

}