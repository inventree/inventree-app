/*
 * Widget tests for the part pricing screen (regression tests for B5).
 *
 * The "override" rows previously displayed the overall price range,
 * and were shown whenever an overall price existed.
 *
 * No server is required.
 */

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:one_context/one_context.dart";

import "package:inventree/helpers.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/part/part_pricing.dart";
import "package:inventree/widget/refreshable_state.dart";

import "../setup.dart";
import "harness.dart";

// Display the pricing screen for [pricing] data, and wait for it to load
Future<void> pumpPricing(
  WidgetTester tester,
  Map<String, dynamic> pricing,
) async {
  final screen = PartPricingWidget(
    part: InvenTreePart.fromJson({"pk": 1, "name": "Widget"}),
    partPricing: InvenTreePartPricing.fromJson(pricing),
  );

  await pumpScreen(tester, screen);

  final state =
      tester.state(find.byWidget(screen)) as RefreshableState<StatefulWidget>;

  await waitUntil(tester, () => state.loaded, reason: "pricing loaded");
  await idle(tester);

  // Allow the image cache (part thumbnail) to complete its cleanup timer
  await tester.pump(const Duration(seconds: 11));
}

// The value displayed in the row titled [title]
Finder rowValue(String title, String value) => find.descendant(
  of: find.widgetWithText(ListTile, title),
  matching: find.text(value),
);

void main() {
  setupTestEnv();
  mockSharedPreferences();

  setUp(() {
    OneContext().key = GlobalKey<NavigatorState>();
    useNewTempDirectory();
  });

  testWidgets("Override prices are displayed", (tester) async {
    await pumpPricing(tester, {
      "currency": "AUD",
      "overall_min": 1,
      "overall_max": 10,
      "override_min": 2.5,
      "override_min_currency": "AUD",
      "override_max": 7.5,
      "override_max_currency": "USD",
    });

    expect(
      rowValue(L10().priceOverrideMin, renderCurrency(2.5, "AUD")),
      findsOneWidget,
    );

    expect(
      rowValue(L10().priceOverrideMax, renderCurrency(7.5, "USD")),
      findsOneWidget,
    );

    // The overall range is not shown as an override
    expect(
      rowValue(L10().priceOverrideMin, renderCurrency(1, "AUD")),
      findsNothing,
    );

    expect(
      rowValue(L10().priceOverrideMax, renderCurrency(10, "USD")),
      findsNothing,
    );
  });

  testWidgets("No override rows without overrides", (tester) async {
    await pumpPricing(tester, {
      "currency": "AUD",
      "overall_min": 1,
      "overall_max": 10,
    });

    expect(find.text(L10().priceRange), findsOneWidget);
    expect(find.text(L10().priceOverrideMin), findsNothing);
    expect(find.text(L10().priceOverrideMax), findsNothing);
  });

  testWidgets("Single override", (tester) async {
    await pumpPricing(tester, {
      "currency": "AUD",
      "overall_min": 1,
      "overall_max": 10,
      "override_max": 7.5,
    });

    expect(find.text(L10().priceOverrideMin), findsNothing);

    // Currency falls back to the pricing currency
    expect(
      rowValue(L10().priceOverrideMax, renderCurrency(7.5, "AUD")),
      findsOneWidget,
    );
  });
}
