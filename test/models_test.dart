/*
 * Unit tests for accessing various model classes via the API
 */

import "package:test/test.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";

import "setup.dart";

void main() {
  setupTestEnv();

  setUp(() async {
    await connectToTestServer();
  });

  group("Category Tests:", () {
    test("Basics", () async {
      assert(InvenTreePartCategory().URL == "part/category/");
    });

    test("List Categories", () async {
      List<InvenTreeModel> results;

      // List *all* categories
      results = await InvenTreePartCategory().list();
      expect(results.length, greaterThanOrEqualTo(28));

      for (var result in results) {
        assert(result is InvenTreePartCategory);
      }

      // Filter by parent category ("Electronics")
      results = await InvenTreePartCategory().list(filters: {"parent": "1"});

      expect(results.length, equals(6));
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
      expect(results.length, greaterThanOrEqualTo(438));

      // List with active filter
      results = await InvenTreePart().list(filters: {"active": "true"});
      expect(results.length, greaterThanOrEqualTo(410));

      for (var result in results) {
        // results must be InvenTreePart instances
        assert(result is InvenTreePart);
      }

      // Filter by category ("Enclosures")
      results = await InvenTreePart().list(filters: {"category": "15"});

      expect(results.length, equals(5));
    });

    test("Part Detail", () async {
      final result = await InvenTreePart().get(1);

      assert(result != null);
      assert(result is InvenTreePart);

      if (result != null) {
        InvenTreePart part = result as InvenTreePart;

        // Check some basic properties of the part
        assert(part.name == "R_10R_0402_1%");
        assert(part.fullname == "R_10R_0402_1%");
        assert(part.description == "10R resistor in 0402 SMD package");
        assert(part.categoryId == 5);
        assert(part.categoryName == "Resistors");
        assert(part.image == "/media/part_images/0402.jpg");
        assert(part.thumbnail == "/media/part_images/0402.thumbnail.jpg");

        // Stock information
        assert(part.inStock > 0);
        assert(part.unallocatedStock <= part.inStock);
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
        assert(part.name == "R_10R_0402_1%");

        // Change the name to something else

        response = await part.update(values: {"name": "Woogle"});

        assert(response.isValid());
        assert(response.statusCode == 200);

        assert(await part.reload());
        assert(part.name == "Woogle");

        // And change it back again
        response = await part.update(values: {"name": "R_10R_0402_1%"});

        assert(response.isValid());
        assert(response.statusCode == 200);

        assert(await part.reload());
        assert(part.name == "R_10R_0402_1%");
      }
    });
  });
}
