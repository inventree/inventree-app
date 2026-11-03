/*
 * Widget tests for the settings screens.
 *
 * Settings and profiles are stored in the on-disk preferences database,
 * so database operations are waited on with settle() (see harness.dart)
 */

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:flutter_test/flutter_test.dart";
import "package:one_context/one_context.dart";
import "package:package_info_plus/package_info_plus.dart";

import "package:inventree/l10.dart";
import "package:inventree/preferences.dart";
import "package:inventree/settings/about.dart";
import "package:inventree/settings/app_settings.dart";
import "package:inventree/settings/barcode_settings.dart";
import "package:inventree/settings/home_settings.dart";
import "package:inventree/settings/login.dart";
import "package:inventree/settings/part_settings.dart";
import "package:inventree/settings/purchase_order_settings.dart";
import "package:inventree/settings/sales_order_settings.dart";
import "package:inventree/settings/select_server.dart";
import "package:inventree/settings/settings.dart";
import "package:inventree/settings/stock_settings.dart";
import "package:inventree/user_profile.dart";

import "../fake_server.dart";
import "../setup.dart";
import "harness.dart";

const String profileName = "Settings Widget Test";

UserProfileDBManager get manager => UserProfileDBManager();

InvenTreeSettingsManager get settings => InvenTreeSettingsManager();

// Wait until the stored value for [key] matches [expected]
Future<void> waitForSetting(
  WidgetTester tester,
  String key,
  dynamic expected,
) async {
  dynamic value;

  for (int i = 0; i < 50; i++) {
    value = await settle(tester, settings.getValue(key, null));

    if (value == expected) {
      break;
    }
  }

  expect(value, equals(expected), reason: "setting '${key}'");
}

Future<void> setSettings(WidgetTester tester, Map<String, dynamic> values) {
  return settle(
    tester,
    Future.wait([
      for (final entry in values.entries)
        settings.setValue(entry.key, entry.value),
    ]),
  );
}

Future<void> removeSettings(WidgetTester tester, Iterable<String> keys) {
  return settle(
    tester,
    Future.wait([for (final key in keys) settings.removeValue(key)]),
  );
}

// Find the ListTile with the given title
Finder tile(String title) => find.widgetWithText(ListTile, title);

Finder switchFinder(String title) =>
    find.descendant(of: tile(title), matching: find.byType(Switch));

bool switchValue(WidgetTester tester, String title) =>
    tester.widget<Switch>(switchFinder(title)).value;

/*
 * A boolean setting, displayed as a switch with the given title
 */
class SwitchSetting {
  const SwitchSetting(this.title, this.key, this.defaultValue);

  final String title;
  final String key;
  final bool defaultValue;
}

/*
 * Check that each switch setting on [screen]:
 * - Displays the stored value
 * - Updates the stored value when toggled
 */
Future<void> checkSwitchSettings(
  WidgetTester tester,
  Widget screen,
  List<SwitchSetting> switches,
) async {
  // Store the non-default value, to check it is loaded
  await setSettings(tester, {for (final s in switches) s.key: !s.defaultValue});

  await pumpScreen(tester, screen);

  await waitUntil(
    tester,
    () => switches.every(
      (s) =>
          switchFinder(s.title).evaluate().isNotEmpty &&
          switchValue(tester, s.title) != s.defaultValue,
    ),
    reason: "stored values are displayed",
  );

  for (final s in switches) {
    await tester.tap(switchFinder(s.title));
    await tester.pump();

    expect(switchValue(tester, s.title), equals(s.defaultValue));

    await waitForSetting(tester, s.key, s.defaultValue);
  }

  await removeSettings(tester, switches.map((s) => s.key));
}

void main() {
  setupTestEnv();
  mockSharedPreferences();

  setUp(() {
    // A new navigator for each test, so no state carries over
    OneContext().key = GlobalKey<NavigatorState>();
  });

  group("Switch Settings:", () {
    testWidgets("App Settings", (tester) async {
      await checkSwitchSettings(tester, InvenTreeAppSettingsWidget(), [
        SwitchSetting(L10().showPkValue, INV_SHOW_PK, false),
        SwitchSetting(L10().history, INV_SHOW_HISTORY, false),
        SwitchSetting(L10().labelPrinting, INV_ENABLE_LABEL_PRINTING, true),
        SwitchSetting(L10().strictHttps, INV_STRICT_HTTPS, false),
        SwitchSetting(L10().errorReportUpload, INV_REPORT_ERRORS, true),
        SwitchSetting(L10().serverError, INV_SOUNDS_SERVER, true),
        SwitchSetting(L10().barcodeTones, INV_SOUNDS_BARCODE, true),
      ]);

      // Dark mode reflects (and changes) the current theme
      expect(switchValue(tester, L10().darkMode), isFalse);

      await tester.tap(switchFinder(L10().darkMode));
      await tester.pumpAndSettle();

      expect(switchValue(tester, L10().darkMode), isTrue);
      expect(
        Theme.of(tester.element(switchFinder(L10().darkMode))).brightness,
        equals(Brightness.dark),
      );

      await tester.tap(switchFinder(L10().darkMode));
      await tester.pumpAndSettle();

      expect(switchValue(tester, L10().darkMode), isFalse);
    });

    testWidgets("Home Screen Settings", (tester) async {
      await checkSwitchSettings(tester, HomeScreenSettingsWidget(), [
        SwitchSetting(L10().homeShowSubscribed, INV_HOME_SHOW_SUBSCRIBED, true),
        SwitchSetting(L10().homeShowPo, INV_HOME_SHOW_PO, true),
        SwitchSetting(L10().homeShowSo, INV_HOME_SHOW_SO, true),
        SwitchSetting(L10().homeShowShipments, INV_HOME_SHOW_SHIPMENTS, true),
        SwitchSetting(L10().homeShowSuppliers, INV_HOME_SHOW_SUPPLIERS, true),
        SwitchSetting(L10().homeShowTransfer, INV_HOME_SHOW_TRANSFER, true),
        SwitchSetting(L10().homeShowCustomers, INV_HOME_SHOW_CUSTOMERS, true),
      ]);
    });

    testWidgets("Barcode Settings", (tester) async {
      await checkSwitchSettings(tester, InvenTreeBarcodeSettingsWidget(), [
        SwitchSetting(L10().barcodeScanSingle, INV_BARCODE_SCAN_SINGLE, false),
      ]);
    });

    testWidgets("Part Settings", (tester) async {
      await checkSwitchSettings(tester, InvenTreePartSettingsWidget(), [
        SwitchSetting(L10().bom, INV_PART_SHOW_BOM, true),
        SwitchSetting(L10().partPricing, INV_PART_SHOW_PRICING, true),
        SwitchSetting(
          L10().partRequirements,
          INV_PART_SHOW_REQUIREMENTS,
          false,
        ),
      ]);
    });

    testWidgets("Stock Settings", (tester) async {
      await checkSwitchSettings(tester, InvenTreeStockSettingsWidget(), [
        SwitchSetting(L10().testResults, INV_STOCK_SHOW_TESTS, true),
        SwitchSetting(L10().confirmScan, INV_STOCK_CONFIRM_SCAN, false),
      ]);
    });

    testWidgets("Purchase Order Settings", (tester) async {
      await checkSwitchSettings(
        tester,
        InvenTreePurchaseOrderSettingsWidget(),
        [
          SwitchSetting(L10().purchaseOrderEnable, INV_PO_ENABLE, true),
          SwitchSetting(
            L10().purchaseOrderShowCamera,
            INV_PO_SHOW_CAMERA,
            true,
          ),
          SwitchSetting(
            L10().purchaseOrderConfirmScan,
            INV_PO_CONFIRM_SCAN,
            true,
          ),
        ],
      );
    });

    testWidgets("Sales Order Settings", (tester) async {
      await checkSwitchSettings(tester, InvenTreeSalesOrderSettingsWidget(), [
        SwitchSetting(L10().salesOrderEnable, INV_SO_ENABLE, true),
        SwitchSetting(L10().salesOrderShowCamera, INV_SO_SHOW_CAMERA, true),
      ]);
    });
  });

  group("App Settings:", () {
    final Map<int, IconData> orientationIcons = {
      SCREEN_ORIENTATION_SYSTEM: Icons.screen_rotation,
      SCREEN_ORIENTATION_PORTRAIT: Icons.screen_lock_portrait,
      SCREEN_ORIENTATION_LANDSCAPE: Icons.screen_lock_landscape,
    };

    orientationIcons.forEach((orientation, icon) {
      testWidgets("Orientation ${orientation}", (tester) async {
        await setSettings(tester, {INV_SCREEN_ORIENTATION: orientation});

        await pumpScreen(tester, InvenTreeAppSettingsWidget());

        await waitUntil(
          tester,
          () => find
              .descendant(
                of: tile(L10().orientation),
                matching: find.byIcon(icon),
              )
              .evaluate()
              .isNotEmpty,
        );

        await removeSettings(tester, [INV_SCREEN_ORIENTATION]);
      });
    });

    testWidgets("Language", (tester) async {
      await pumpScreen(tester, InvenTreeAppSettingsWidget());

      await waitUntil(
        tester,
        () => find
            .descendant(
              of: tile(L10().language),
              matching: find.text(L10().languageDefault),
            )
            .evaluate()
            .isNotEmpty,
        reason: "default language is displayed",
      );

      await settle(
        tester,
        settings.setSelectedLocale(const Locale("de", "DE")),
      );

      // Remove the existing screen, so that the settings are reloaded
      await tester.pumpWidget(const SizedBox());

      await pumpScreen(tester, InvenTreeAppSettingsWidget());

      await waitUntil(
        tester,
        () => find
            .descendant(
              of: tile(L10().language),
              matching: find.textContaining("German"),
            )
            .evaluate()
            .isNotEmpty,
        reason: "selected language is displayed",
      );

      await settle(tester, settings.setSelectedLocale(null));
    });
  });

  group("Barcode Settings:", () {
    final Map<int, IconData> controllerIcons = {
      BARCODE_CONTROLLER_CAMERA: TablerIcons.camera,
      BARCODE_CONTROLLER_WEDGE: Icons.barcode_reader,
      BARCODE_CONTROLLER_INTENT: TablerIcons.arrow_badge_right,
    };

    controllerIcons.forEach((controller, icon) {
      testWidgets("Scan Controller ${controller}", (tester) async {
        await setSettings(tester, {INV_BARCODE_SCAN_TYPE: controller});

        await pumpScreen(tester, InvenTreeBarcodeSettingsWidget());

        await waitUntil(
          tester,
          () => find
              .descendant(
                of: tile(L10().barcodeScanController),
                matching: find.byIcon(icon),
              )
              .evaluate()
              .isNotEmpty,
        );

        await removeSettings(tester, [INV_BARCODE_SCAN_TYPE]);
      });
    });

    testWidgets("Scan Delay", (tester) async {
      await setSettings(tester, {INV_BARCODE_SCAN_DELAY: 750});

      await pumpScreen(tester, InvenTreeBarcodeSettingsWidget());

      await waitUntil(tester, () => find.text("750 ms").evaluate().isNotEmpty);

      // Enter a new value, and check it is limited to the allowed range
      final Map<String, int> values = {
        "50": 100,
        "1000": 1000,
        "99999": 2500,
        "abc": 2500,
      };

      for (final entry in values.entries) {
        await tester.tap(find.textContaining(" ms"));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          entry.key,
        );

        await tester.tap(find.text(L10().ok));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text("${entry.value} ms"), findsOneWidget);

        await waitForSetting(tester, INV_BARCODE_SCAN_DELAY, entry.value);
      }

      // Cancel does not change the value
      await tester.tap(find.textContaining(" ms"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        "500",
      );

      await tester.tap(find.text(L10().cancel));
      await tester.pumpAndSettle();

      expect(find.text("2500 ms"), findsOneWidget);

      await removeSettings(tester, [INV_BARCODE_SCAN_DELAY]);
    });
  });

  group("Settings Menu:", () {
    testWidgets("Navigation", (tester) async {
      await pumpScreen(tester, InvenTreeSettingsWidget());

      // Each menu item opens the matching settings screen
      final Map<String, Type> screens = {
        L10().server: InvenTreeSelectServerWidget,
        L10().appSettings: InvenTreeAppSettingsWidget,
        L10().homeScreen: HomeScreenSettingsWidget,
        L10().barcodes: InvenTreeBarcodeSettingsWidget,
        L10().part: InvenTreePartSettingsWidget,
        L10().stock: InvenTreeStockSettingsWidget,
        L10().purchaseOrder: InvenTreePurchaseOrderSettingsWidget,
        L10().salesOrder: InvenTreeSalesOrderSettingsWidget,
      };

      for (final entry in screens.entries) {
        await tester.tap(tile(entry.key));
        await tester.pumpAndSettle();

        expect(find.byType(entry.value), findsOneWidget, reason: entry.key);

        // Allow the screen to finish loading, before returning
        await waitUntil(tester, () => true);

        OneContext().key.currentState!.pop();
        await tester.pumpAndSettle();

        expect(find.byType(entry.value), findsNothing);
      }
    });

    testWidgets("About", (tester) async {
      await pumpScreen(tester, InvenTreeSettingsWidget());

      await tester.tap(tile(L10().about));

      await waitUntil(
        tester,
        () => find.byType(InvenTreeAboutWidget).evaluate().isNotEmpty,
      );

      await tester.pumpAndSettle();

      expect(find.text(L10().appAbout), findsOneWidget);
      expect(find.text(L10().notConnected), findsOneWidget);
      expect(find.text("inventree.inventree_app"), findsOneWidget);
      expect(find.text("0.0.0 - Build 0"), findsOneWidget);

      // Release notes are loaded from the app assets
      await tester.tap(tile(L10().releaseNotes));
      await waitUntil(tester, () => !find.text(L10().appAbout).hasFound);
      await tester.pumpAndSettle();

      expect(find.byType(InvenTreeAboutWidget), findsNothing);

      OneContext().key.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(tile(L10().credits));
      await waitUntil(
        tester,
        () =>
            find.byType(InvenTreeAboutWidget).hitTestable().evaluate().isEmpty,
      );
      await tester.pumpAndSettle();

      OneContext().key.currentState!.pop();
      await tester.pumpAndSettle();

      expect(find.byType(InvenTreeAboutWidget), findsOneWidget);

      // The update check times out after 10 seconds
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets("About Widget", (tester) async {
      await pumpScreen(
        tester,
        InvenTreeAboutWidget(
          PackageInfo(
            appName: "InvenTree",
            packageName: "test.package",
            version: "1.2.3",
            buildNumber: "45",
          ),
        ),
      );

      expect(find.text("test.package"), findsOneWidget);
      expect(find.text("1.2.3 - Build 45"), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
    });
  });

  group("Select Server:", () {
    late FakeInvenTreeServer server;

    setUp(() async {
      server = await FakeInvenTreeServer.start();
    });

    tearDown(() async {
      await server.close();
    });

    // Create a fresh test profile, pointing at the fake server
    Future<void> deleteProfile(WidgetTester tester, String name) async {
      final existing = await settle(tester, manager.getProfileByName(name));

      if (existing != null) {
        await settle(tester, manager.deleteProfile(existing));
      }
    }

    Future<UserProfile> testProfile(WidgetTester tester) async {
      for (final name in [profileName, "${profileName} (edited)"]) {
        await deleteProfile(tester, name);
      }

      await settle(
        tester,
        manager.addProfile(UserProfile(name: profileName, server: server.url)),
      );

      final UserProfile? profile = await settle(
        tester,
        manager.getProfileByName(profileName),
      );

      return profile!;
    }

    Future<void> pumpSelectServer(WidgetTester tester) async {
      await pumpScreen(tester, InvenTreeSelectServerWidget());

      await waitUntil(
        tester,
        () => find.text(profileName).evaluate().isNotEmpty,
        reason: "profile is listed",
      );
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets("List Profiles", (tester) async {
      await testProfile(tester);
      await pumpSelectServer(tester);

      expect(find.text(L10().profileSelect), findsOneWidget);
      expect(find.text(server.url), findsOneWidget);

      await deleteProfile(tester, profileName);
    });

    testWidgets("Add Profile", (tester) async {
      await testProfile(tester);
      await pumpSelectServer(tester);

      const String newName = "${profileName} (new)";

      await deleteProfile(tester, newName);

      await tester.tap(find.byIcon(TablerIcons.circle_plus));
      await tester.pumpAndSettle();

      expect(find.text(L10().profileAdd), findsOneWidget);

      Future<void> save() async {
        await tester.tap(find.byIcon(TablerIcons.circle_check));
        await tester.pumpAndSettle();
      }

      // Empty values
      await save();

      expect(find.text(L10().valueCannotBeEmpty), findsOneWidget);
      expect(find.text(L10().serverEmpty), findsOneWidget);

      await tester.enterText(field(L10().profileName), newName);

      // Invalid server addresses
      final Map<String, String> invalid = {
        "http://bad host": L10().invalidHost,
        "server.com": L10().invalidHost,
        "ftp://server.com": L10().serverStart,
      };

      for (final entry in invalid.entries) {
        await tester.enterText(field(L10().server), entry.key);
        await save();

        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
        expect(find.text(L10().profileAdd), findsOneWidget);
      }

      await tester.enterText(field(L10().server), "https://new.server.com");

      await tester.tap(find.byIcon(TablerIcons.circle_check));

      await waitUntil(
        tester,
        () => find.text(newName).evaluate().isNotEmpty,
        reason: "new profile is listed",
      );

      final UserProfile? profile = await settle(
        tester,
        manager.getProfileByName(newName),
      );

      expect(profile?.server, equals("https://new.server.com"));

      await deleteProfile(tester, newName);
      await deleteProfile(tester, profileName);
    });

    testWidgets("Edit Profile", (tester) async {
      final profile = await testProfile(tester);
      await pumpSelectServer(tester);

      // Open the profile actions menu
      await tester.tap(
        find.descendant(
          of: tile(profileName),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(L10().profileConnect), findsOneWidget);
      expect(find.text(L10().profileLogout), findsOneWidget);
      expect(find.text(L10().profileDelete), findsOneWidget);

      await tester.tap(find.text(L10().profileEdit));
      await tester.pumpAndSettle();

      // Existing values are displayed
      expect(find.text(L10().profileEdit), findsOneWidget);
      expect(find.text(profileName), findsOneWidget);
      expect(find.text(server.url), findsOneWidget);

      await tester.enterText(
        field(L10().profileName),
        "${profileName} (edited)",
      );

      await tester.tap(find.byIcon(TablerIcons.circle_check));

      await waitUntil(
        tester,
        () => find.text("${profileName} (edited)").evaluate().isNotEmpty,
        reason: "edited profile is listed",
      );

      final UserProfile? edited = await settle(
        tester,
        manager.getProfileByKey(profile.key!),
      );

      expect(edited?.name, equals("${profileName} (edited)"));
      expect(edited?.server, equals(server.url));

      await deleteProfile(tester, "${profileName} (edited)");
    });

    testWidgets("Logout Profile", (tester) async {
      await testProfile(tester);
      await pumpSelectServer(tester);

      // Long press is a shortcut to the actions menu
      await tester.longPress(tile(profileName));
      await tester.pumpAndSettle();

      await tester.tap(find.text(L10().profileLogout));

      // The profile has no stored session
      await waitUntil(
        tester,
        () => find
            .descendant(
              of: tile(profileName),
              matching: find.byIcon(TablerIcons.user_cancel),
            )
            .evaluate()
            .isNotEmpty,
      );

      await deleteProfile(tester, profileName);
    });

    testWidgets("Connect Without Session", (tester) async {
      await testProfile(tester);
      await pumpSelectServer(tester);

      // A profile without a session opens the login screen
      await tester.tap(tile(profileName));

      await waitUntil(
        tester,
        () => find.byType(InvenTreeLoginWidget).evaluate().isNotEmpty,
        reason: "login screen is displayed",
      );

      await tester.pumpAndSettle();

      OneContext().key.currentState!.pop();

      await waitUntil(
        tester,
        () => find.byType(InvenTreeLoginWidget).evaluate().isEmpty,
      );

      await deleteProfile(tester, profileName);
    });

    testWidgets("Connection Check", (tester) async {
      await pumpScreen(tester, ProfileEditWidget(null));

      final Finder checkButton = find.text(L10().connectionCheck);

      Finder statusIcon(IconData icon) => find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byIcon(icon),
      );

      expect(statusIcon(TablerIcons.question_mark), findsOneWidget);

      // Invalid form - no check is performed
      await tester.tap(checkButton);
      await tester.pumpAndSettle();

      expect(find.text(L10().serverEmpty), findsOneWidget);
      expect(server.received("GET", "api/"), isEmpty);

      await tester.enterText(field(L10().profileName), profileName);
      await tester.enterText(field(L10().server), server.url);

      await tester.tap(checkButton);

      await waitUntil(
        tester,
        () => statusIcon(TablerIcons.circle_check).evaluate().isNotEmpty,
        reason: "server check passes",
      );

      // Server is not available
      final FakeInvenTreeServer closed = await settle(
        tester,
        FakeInvenTreeServer.start(),
      );

      final String closedUrl = closed.url;

      await settle(tester, closed.close());

      await tester.enterText(field(L10().server), closedUrl);
      await tester.tap(checkButton);

      await waitUntil(
        tester,
        () => statusIcon(TablerIcons.circle_x).evaluate().isNotEmpty,
        reason: "server check fails",
      );

      // Allow the idle HTTP connection (from the first check) to expire
      await tester.pump(const Duration(seconds: 16));
    });
  });
}
