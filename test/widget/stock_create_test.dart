/*
 * Widget tests for creating stock items (regression tests for B4).
 *
 * Since API v383 the server returns a *list* of created stock items,
 * which previously caused the app to silently ignore the response.
 *
 * These tests require a running InvenTree server (see setup.dart)
 * with the demo dataset loaded. Any stock items created are deleted again.
 */

import "package:dropdown_search/dropdown_search.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:one_context/one_context.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/part/part_detail.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/stock/stock_detail.dart";

import "../setup.dart";
import "harness.dart";

/*
 * Display [screen], wait for it to load,
 * then open the "New Stock Item" form from the actions menu
 */
Future<void> openNewStockItemForm(WidgetTester tester, Widget screen) async {
  await pumpScreen(tester, screen);

  final state =
      tester.state(find.byWidget(screen)) as RefreshableState<StatefulWidget>;

  await waitUntil(tester, () => state.loaded, reason: "${screen} loaded");
  await idle(tester);

  // Open the actions menu
  await tester.tap(find.byIcon(Icons.more_horiz));
  await idle(tester);

  await tester.tap(find.text(L10().stockItemCreate));

  // Form fields are loaded from the server (OPTIONS request)
  await waitUntil(
    tester,
    () => find.byType(Form).evaluate().isNotEmpty,
    reason: "stock item form displayed",
  );

  await idle(tester);
}

// Enter [value] into the text field labelled [label] ("*" if required)
Future<void> enterField(WidgetTester tester, String label, String value) async {
  final Finder field = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText == label ||
            widget.decoration?.labelText == "${label}*"),
  );

  final List<String?> labels = tester
      .widgetList<TextField>(find.byType(TextField, skipOffstage: false))
      .map((w) => w.decoration?.labelText)
      .toList();

  expect(field, findsOneWidget, reason: "form field '${label}' in ${labels}");

  await tester.enterText(field, value);
  await tester.pump();
}

// Submit the displayed form (save button, after "back", in the app bar)
Future<void> submitForm(WidgetTester tester) async {
  await tester.tap(
    find
        .descendant(
          of: find.widgetWithText(AppBar, L10().stockItemCreate),
          matching: find.byType(IconButton),
        )
        .last,
  );

  await step(tester);
}

// Snack messages are not displayed in tests, but are logged (see showSnackIcon)
bool snackShown(String message) =>
    debug_messages.contains("showSnackIcon: '${message}'");

// All text currently displayed (for failure messages)
String screenText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? "")
    .where((s) => s.isNotEmpty)
    .join(" | ");

void main() {
  setupTestEnv();
  mockSharedPreferences();

  setUp(() {
    OneContext().key = GlobalKey<NavigatorState>();
    useNewTempDirectory();
    clearDebugMessage();
  });

  testWidgets("From Location: single item opens", (tester) async {
    await withServer(tester, () async {
      final location = await fetchFirst(
        tester,
        InvenTreeStockLocation(),
        filters: {"structural": "false"},
      );

      final part = await fetchFirst(
        tester,
        InvenTreePart(),
        filters: {
          "active": "true",
          "trackable": "false",
          "virtual": "false",
          "is_template": "false",
        },
      );

      await openNewStockItemForm(tester, LocationDisplayWidget(location));

      // Select the part (related field with an online search)
      await tester.tap(
        find.ancestor(
          of: find.text("Part"),
          matching: find.byType(DropdownSearch<dynamic>),
        ),
      );
      await idle(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        part.name,
      );

      // The online search runs after a 1 second debounce
      await tester.pump(const Duration(seconds: 2));

      // A search result item (not the search text itself)
      final Finder option = find.descendant(
        of: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(InkWell),
        ),
        matching: find.text(part.fullname),
      );

      // Wait for the search request to complete (loading indicator hidden)
      final Finder loading = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(CircularProgressIndicator),
      );

      await waitUntil(
        tester,
        () => loading.evaluate().isEmpty && option.evaluate().isNotEmpty,
        reason: "part '${part.fullname}' in search: ${screenText(tester)}",
      );

      // Items are rendered inside an IgnorePointer, so the hit test cannot
      // resolve to the item itself - the enclosing InkWell handles the tap
      await tester.tap(
        find.ancestor(of: option.first, matching: find.byType(InkWell)).first,
        warnIfMissed: false,
      );
      await idle(tester);

      await waitUntil(
        tester,
        () => find.byType(BottomSheet).evaluate().isEmpty,
        reason: "part selected: ${screenText(tester)}",
      );

      await enterField(tester, "Stock Quantity", "1");
      await submitForm(tester);

      // The new stock item is displayed
      await waitUntil(
        tester,
        () => find.byType(StockDetailWidget).evaluate().isNotEmpty,
        reason: "new stock item opened: ${screenText(tester)}",
      );

      final StockDetailWidget detail = tester.widget(
        find.byType(StockDetailWidget),
      );

      final InvenTreeStockItem item = detail.item;

      try {
        expect(item.pk, greaterThan(0));
        expect(item.partId, equals(part.pk));
        expect(item.locationId, equals(location.pk));
      } finally {
        // Remove the stock item created by this test
        expect(await settle(tester, item.delete()), isTrue);
      }

      await idle(tester);
    });
  });

  testWidgets("From Trackable Part: multiple items", (tester) async {
    await withServer(tester, () async {
      final part = await fetchFirst(
        tester,
        InvenTreePart(),
        filters: {
          "active": "true",
          "trackable": "true",
          "virtual": "false",
          "is_template": "false",
        },
      );

      // Find the next available serial number
      final APIResponse response = await settle(
        tester,
        InvenTreeAPI().get(
          "part/${part.pk}/serial-numbers/",
          expectedStatusCode: 200,
        ),
      );

      final int first =
          int.tryParse((response.data["next"] ?? "").toString()) ?? 0;

      expect(first, greaterThan(0), reason: "next serial number for ${part}");

      final List<String> serials = [
        for (int sn = first; sn < first + 3; sn++) sn.toString(),
      ];

      Future<List<InvenTreeStockItem>> createdItems() async {
        final List<InvenTreeStockItem> items = [];

        for (final String serial in serials) {
          final results = await InvenTreeStockItem().list(
            filters: {"part": part.pk.toString(), "serial": serial},
          );

          items.addAll(results.whereType<InvenTreeStockItem>());
        }

        return items;
      }

      final screen = PartDetailWidget(part);

      try {
        await openNewStockItemForm(tester, screen);

        await enterField(tester, "Stock Quantity", "3");
        await enterField(
          tester,
          "Serial Numbers",
          "${serials.first}-${serials.last}",
        );

        await submitForm(tester);

        // User is notified, and remains on the part screen
        await waitUntil(
          tester,
          () => snackShown(L10().stockItemsCreated(3)),
          reason: "'stock items created' message: ${screenText(tester)}",
        );

        expect(find.byType(StockDetailWidget), findsNothing);
        expect(find.byWidget(screen), findsOneWidget);

        // The part screen is refreshed
        final state =
            tester.state(find.byWidget(screen))
                as RefreshableState<StatefulWidget>;

        await waitUntil(tester, () => state.loaded, reason: "part reloaded");
        await idle(tester);

        // The stock tab lists the new items
        await tester.tap(
          find.descendant(
            of: find.byType(TabBar),
            matching: find.text(L10().stock),
          ),
        );
        await idle(tester);

        // The (paginated) stock list loads separately from the screen
        for (final String serial in serials) {
          await waitUntil(
            tester,
            () => find.textContaining(serial).evaluate().isNotEmpty,
            reason:
                "serial number ${serial} in stock tab: ${screenText(tester)}",
          );
        }

        expect(await settle(tester, createdItems()), hasLength(3));
      } finally {
        // Remove any stock items created by this test
        for (final item in await settle(tester, createdItems())) {
          await settle(tester, item.delete());
        }
      }

      await idle(tester);
    });
  });
}
