import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/widget/home.dart";

void main() {
  Future<void> pumpBadge(
    WidgetTester tester,
    Widget? Function(BuildContext context) buildBadge,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(body: buildBadge(context) ?? const SizedBox());
          },
        ),
      ),
    );
  }

  group("buildOverdueBadge", () {
    testWidgets("renders a badge when there is an overdue count", (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, (context) => buildOverdueBadge(context, 5));

      expect(find.text("5"), findsOneWidget);
      expect(find.byIcon(TablerIcons.calendar_exclamation), findsOneWidget);
    });

    testWidgets("renders nothing when the overdue count is zero", (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, (context) => buildOverdueBadge(context, 0));

      expect(find.text("0"), findsNothing);
    });

    testWidgets("renders nothing when the overdue count is not loaded", (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, (context) => buildOverdueBadge(context, null));

      expect(find.byType(Container), findsNothing);
    });
  });

  group("buildOutstandingBadge", () {
    testWidgets("renders a badge when there is an outstanding count", (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, (context) => buildOutstandingBadge(context, 3));

      expect(find.text("3"), findsOneWidget);
      expect(find.byIcon(TablerIcons.progress), findsOneWidget);
    });

    testWidgets("uses a less prominent color than the overdue badge", (
      WidgetTester tester,
    ) async {
      late Color outstandingColor;
      late Color overdueColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final ColorScheme colors = Theme.of(context).colorScheme;
              outstandingColor = colors.secondaryContainer;
              overdueColor = colors.errorContainer;

              return Scaffold(
                body: Column(
                  children: [
                    buildOutstandingBadge(context, 3)!,
                    buildOverdueBadge(context, 3)!,
                  ],
                ),
              );
            },
          ),
        ),
      );

      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .toList();

      final Color outstandingBadgeColor =
          (containers[0].decoration! as BoxDecoration).color!;
      final Color overdueBadgeColor =
          (containers[1].decoration! as BoxDecoration).color!;

      expect(outstandingBadgeColor, outstandingColor);
      expect(overdueBadgeColor, overdueColor);
      expect(outstandingBadgeColor, isNot(equals(overdueBadgeColor)));
    });
  });

  group("buildOrderBadges", () {
    testWidgets("renders nothing when both counts are empty", (
      WidgetTester tester,
    ) async {
      await pumpBadge(
        tester,
        (context) =>
            buildOrderBadges(context, outstandingCount: null, overdueCount: 0),
      );

      expect(find.byType(Container), findsNothing);
    });

    testWidgets("renders both badges side by side when both counts are set", (
      WidgetTester tester,
    ) async {
      await pumpBadge(
        tester,
        (context) =>
            buildOrderBadges(context, outstandingCount: 7, overdueCount: 2),
      );

      expect(find.text("7"), findsOneWidget);
      expect(find.text("2"), findsOneWidget);
      expect(find.byIcon(TablerIcons.progress), findsOneWidget);
      expect(find.byIcon(TablerIcons.calendar_exclamation), findsOneWidget);
      // One outer Row combining the badges, plus one inner Row per badge
      expect(find.byType(Row), findsNWidgets(3));
    });

    testWidgets("renders only the overdue badge when outstanding is zero", (
      WidgetTester tester,
    ) async {
      await pumpBadge(
        tester,
        (context) =>
            buildOrderBadges(context, outstandingCount: 0, overdueCount: 4),
      );

      expect(find.text("4"), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });
  });
}
