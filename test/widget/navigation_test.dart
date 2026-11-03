/*
 * Widget tests for navigating the app (home screen, menu and search),
 * using the demo dataset.
 *
 * These tests require a running InvenTree server (see setup.dart)
 * with the demo dataset loaded. They do not modify any data.
 *
 * Each screen which is opened is allowed to load, and then closed again.
 * Any exception thrown while building the screens causes the test to fail.
 */

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:one_context/one_context.dart";

import "package:inventree/api.dart";
import "package:inventree/widget/home.dart";
import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/search.dart";

import "../setup.dart";
import "harness.dart";

void main() {
  setupTestEnv();
  mockSharedPreferences();

  setUp(() {
    OneContext().key = GlobalKey<NavigatorState>();
    useNewTempDirectory();
  });

  testWidgets("Home Screen", (tester) async {
    await withServer(tester, () async {
      const Widget home = InvenTreeHomePage();

      await pumpScreen(tester, home);

      // The home screen connects to the selected server
      await waitUntil(
        tester,
        () =>
            InvenTreeAPI().isConnected() &&
            find.byType(Card).evaluate().isNotEmpty,
        reason: "home screen connected",
      );

      await idle(tester);

      // Open each of the home screen tiles
      await followLinks(
        tester,
        home,
        links: () => find
            .descendant(of: find.byType(Card), matching: find.byType(ListTile))
            .hitTestable(),
      );
    });
  });

  testWidgets("Menu", (tester) async {
    await withServer(tester, () async {
      final Widget screen = CategoryDisplayWidget(null);

      await pumpScreen(tester, screen);
      await idle(tester);

      Finder drawerItems() => find
          .descendant(of: find.byType(Drawer), matching: find.byType(ListTile))
          .hitTestable();

      // Open each of the menu items
      await followLinks(
        tester,
        screen,
        links: drawerItems,
        beforeEach: () async {
          if (drawerItems().evaluate().isEmpty) {
            await tester.tap(find.byIcon(Icons.menu));
            await idle(tester);
          }

          expect(drawerItems(), findsWidgets);
        },
      );
    });
  });

  testWidgets("Search", (tester) async {
    await withServer(tester, () async {
      const Widget screen = SearchWidget(true);

      await pumpScreen(tester, screen);
      await idle(tester);

      // Search result tiles (one for each model type)
      Finder results() => find
          .byWidgetPredicate((w) => w is ListTile && w.onTap != null)
          .hitTestable();

      await tester.enterText(find.byType(TextField), "chair");

      await waitUntil(
        tester,
        () => results().evaluate().length > 1,
        reason: "search results displayed",
      );

      await idle(tester);

      // Open each set of search results
      await followLinks(tester, screen, links: results);

      // Clear the search
      await tester.enterText(find.byType(TextField), "");
      await idle(tester);
    });
  });
}
