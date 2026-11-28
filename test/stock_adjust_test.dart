/*
 * Tests for stock adjustment actions (regression tests for B10).
 *
 * adjustStock() previously posted the full item quantity,
 * ignoring the requested quantity.
 *
 * These tests require a running InvenTree server (see setup.dart)
 * with the demo dataset loaded. Any stock items created are deleted again.
 */

import "package:test/test.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";

import "setup.dart";

void main() {
  setupTestEnv();

  late InvenTreePart part;
  late InvenTreeStockLocation source;
  late InvenTreeStockLocation destination;

  // Stock items created by the current test (deleted after each test)
  final List<int> created = [];

  Future<T> first<T>(T model, Map<String, String> filters) async {
    final results = await (model as dynamic).list(
      filters: {...filters, "limit": "2"},
    );

    expect(results, isNotEmpty, reason: "No ${T} matching ${filters}");
    return results.first as T;
  }

  // Create a new stock item with [quantity] at the source location
  // Note: Stock creation returns a list of created items (API v383+),
  // which InvenTreeModel.create() must handle
  Future<InvenTreeStockItem> createItem(double quantity) async {
    final item = await InvenTreeStockItem().create({
      "part": part.pk,
      "location": source.pk,
      "quantity": quantity,
      "notes": "Created by stock_adjust_test",
    });

    expect(item, isA<InvenTreeStockItem>());
    expect(item!.pk, greaterThan(0));

    created.add(item.pk);

    expect((item as InvenTreeStockItem).quantity, equals(quantity));
    expect(item.partId, equals(part.pk));

    return item;
  }

  // Reload [item] from the server
  Future<InvenTreeStockItem> reload(InvenTreeStockItem item) async {
    expect(await item.reload(), isTrue);
    return item;
  }

  // Stock items for the test part at [location], excluding [exclude]
  Future<List<InvenTreeStockItem>> itemsAt(
    InvenTreeStockLocation location, {
    Set<int> exclude = const {},
  }) async {
    final results = await InvenTreeStockItem().list(
      filters: {
        "part": part.pk.toString(),
        "location": location.pk.toString(),
        "cascade": "false",
      },
    );

    return results
        .whereType<InvenTreeStockItem>()
        .where((item) => !exclude.contains(item.pk))
        .toList();
  }

  setUpAll(() async {
    await connectToTestServer();

    part = await first(InvenTreePart(), {
      "active": "true",
      "trackable": "false",
      "virtual": "false",
      "is_template": "false",
    });

    final locations = await InvenTreeStockLocation().list(
      filters: {"structural": "false", "limit": "2"},
    );

    expect(locations, hasLength(2));
    source = locations[0] as InvenTreeStockLocation;
    destination = locations[1] as InvenTreeStockLocation;
  });

  tearDown(() async {
    for (final pk in created) {
      await InvenTreeStockItem.fromJson({"pk": pk}).delete();
    }

    created.clear();
  });

  group("Adjust Quantity:", () {
    test("Count (partial)", () async {
      final item = await createItem(10);

      expect(await item.countStock(7), isTrue);
      expect((await reload(item)).quantity, equals(7));
    });

    test("Count (full)", () async {
      final item = await createItem(10);

      expect(await item.countStock(10), isTrue);
      expect((await reload(item)).quantity, equals(10));
    });

    test("Add", () async {
      final item = await createItem(10);

      expect(await item.addStock(3), isTrue);
      expect((await reload(item)).quantity, equals(13));
    });

    test("Remove (partial)", () async {
      final item = await createItem(10);

      expect(await item.removeStock(4), isTrue);
      expect((await reload(item)).quantity, equals(6));
    });

    test("Remove (full)", () async {
      final item = await createItem(10);

      expect(await item.removeStock(10), isTrue);

      // The item may be deleted when depleted (depending on server settings)
      final InvenTreeStockItem check = InvenTreeStockItem.fromJson({
        "pk": item.pk,
      });

      if (await check.reload()) {
        expect(check.quantity, equals(0));
      }
    });

    test("Negative quantity is rejected", () async {
      final item = await createItem(10);

      expect(await item.addStock(-1), isFalse);
      expect(await item.removeStock(-1), isFalse);
      expect((await reload(item)).quantity, equals(10));
    });
  });

  group("Transfer:", () {
    test("Full quantity (default)", () async {
      final item = await createItem(10);

      expect(await item.transferStock(destination.pk), isTrue);

      final moved = await reload(item);
      expect(moved.locationId, equals(destination.pk));
      expect(moved.quantity, equals(10));
    });

    test("Full quantity (explicit)", () async {
      final item = await createItem(10);

      expect(await item.transferStock(destination.pk, quantity: 10), isTrue);

      final moved = await reload(item);
      expect(moved.locationId, equals(destination.pk));
      expect(moved.quantity, equals(10));
    });

    test("Partial quantity", () async {
      final item = await createItem(10);

      // Existing stock at the destination (not created by this test)
      final before = (await itemsAt(destination)).map((i) => i.pk).toSet();

      expect(await item.transferStock(destination.pk, quantity: 4), isTrue);

      // The remainder stays at the source location
      final remainder = await reload(item);
      expect(remainder.locationId, equals(source.pk));
      expect(remainder.quantity, equals(6));

      // The transferred quantity is split into a new item at the destination
      final split = await itemsAt(destination, exclude: {...before, item.pk});

      created.addAll(split.map((i) => i.pk));

      expect(split, hasLength(1));
      expect(split.first.quantity, equals(4));
    });
  });

  test("Create is rejected with invalid data", () async {
    // Missing part - the server returns validation errors (not an item)
    final item = await InvenTreeStockItem().create({
      "location": source.pk,
      "quantity": 1,
    });

    expect(item, isNull);
  });

  test("Serialized stock cannot be counted", () async {
    final item = InvenTreeStockItem.fromJson({
      "pk": 1,
      "quantity": 1,
      "serial": "123",
    });

    expect(item.isSerialized(), isTrue);
    expect(await item.countStock(1), isFalse);
  });
}
