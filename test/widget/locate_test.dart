/*
 * Widget tests for locating a stock item / location (regression tests for B16).
 *
 * With more than one "locate" plugin, the user selects a plugin from a form.
 * Previously the locate request was sent (with an empty plugin) as soon as
 * the form was opened, as launchApiForm() returned before the form was closed.
 *
 * Uses an in-process fake server (see fake_server.dart).
 */

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_method.dart";
import "package:inventree/l10.dart";
import "package:inventree/user_profile.dart";

import "../fake_server.dart";
import "../setup.dart";
import "harness.dart";

const String profileName = "Locate Widget Test";

UserProfileDBManager get manager => UserProfileDBManager();

Map<String, dynamic> locatePlugin(String key) => {
  "key": key,
  "active": true,
  "meta": {"human_name": "Plugin ${key}"},
  "mixins": {
    "locate": {"key": "locate"},
  },
};

void main() {
  setupTestEnv();
  mockSharedPreferences();

  late FakeInvenTreeServer server;

  setUp(() async {
    server = await FakeInvenTreeServer.start();

    server.always(
      "GET",
      "api/plugins/",
      (_) => FakeResponse(
        200,
        body: [locatePlugin("first"), locatePlugin("second")],
      ),
    );

    server.always("POST", "api/locate/", (_) => FakeResponse(200, body: {}));
  });

  tearDown(() async {
    await server.close();
  });

  // Connect to the fake server, and show a screen to launch the form from
  Future<BuildContext> setupScreen(WidgetTester tester) async {
    final UserProfile? existing = await settle(
      tester,
      manager.getProfileByName(profileName),
    );

    if (existing != null) {
      await settle(tester, manager.deleteProfile(existing));
    }

    await settle(
      tester,
      manager.addProfile(UserProfile(name: profileName, server: server.url)),
    );

    final UserProfile profile = (await settle(
      tester,
      manager.getProfileByName(profileName),
    ))!;

    addTearDown(() => manager.deleteProfile(profile));

    final result = await settle(
      tester,
      InvenTreeAuth().beginLogin(
        profile,
        PasswordAuthMethod("user", "password"),
      ),
    );

    expect(result.authenticated, isTrue);
    expect(
      await settle(tester, InvenTreeAPI().connectToServer(profile)),
      isTrue,
    );

    expect(InvenTreeAPI().getPlugins(mixin: "locate"), hasLength(2));

    late BuildContext context;

    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (ctx) {
            context = ctx;
            return const Text("Locate Test");
          },
        ),
      ),
    );

    return context;
  }

  // Start locating an item, and wait for the plugin form to be displayed.
  // [onComplete] is called when locateItemOrLocation() completes
  Future<void> startLocate(
    WidgetTester tester,
    void Function() onComplete,
  ) async {
    final BuildContext context = await setupScreen(tester);

    InvenTreeAPI()
        .locateItemOrLocation(context, item: 5)
        .then((_) => onComplete());

    await waitUntil(
      tester,
      () => find.text(L10().locateLocation).evaluate().isNotEmpty,
      reason: "plugin selection form displayed",
    );
  }

  testWidgets("Locate request waits for plugin selection", (tester) async {
    bool complete = false;

    await startLocate(tester, () => complete = true);

    // Wait for any (incorrect) request to arrive
    for (int i = 0; i < 20; i++) {
      await step(tester);
    }

    expect(server.received("POST", "api/locate/"), isEmpty);
    expect(complete, isFalse);

    // Submit the form (with the default plugin selected)
    await tester.tap(find.byIcon(TablerIcons.location_search));

    await waitUntil(tester, () => complete, reason: "locate complete");

    final requests = server.received("POST", "api/locate/");

    expect(requests, hasLength(1));
    expect(requests.first.json, equals({"plugin": "first", "item": "5"}));

    await disconnectInWidgetTest(tester);
  });

  testWidgets("Cancelled plugin selection sends no request", (tester) async {
    bool complete = false;

    await startLocate(tester, () => complete = true);

    await tester.pageBack();

    await waitUntil(tester, () => complete, reason: "locate complete");

    for (int i = 0; i < 10; i++) {
      await step(tester);
    }

    expect(server.received("POST", "api/locate/"), isEmpty);

    await disconnectInWidgetTest(tester);
  });
}
