/*
 * Shared helpers for widget tests.
 *
 * Widget tests run in a "fake async" zone, where time only advances when the
 * test pumps the widget tree. File and network access (the preferences
 * database, the InvenTree server) needs real time to progress as well,
 * so these helpers alternate between the two (see step() and settle()).
 */

import "package:adaptive_theme/adaptive_theme.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_localized_locales/flutter_localized_locales.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:flutter_test/flutter_test.dart";
import "package:one_context/one_context.dart";

import "package:inventree/api.dart";
import "package:inventree/l10n/collected/app_localizations.dart";
import "package:inventree/l10n/supported_locales.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/refreshable_state.dart";

import "../setup.dart";

// In-memory shared preferences (used by AdaptiveTheme to store the theme mode)
final Map<String, Object> sharedPreferences = {};

void mockSharedPreferences() {
  const MethodChannel channel = MethodChannel(
    "plugins.flutter.io/shared_preferences",
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        final Map<dynamic, dynamic> args =
            (call.arguments as Map<dynamic, dynamic>?) ?? {};

        switch (call.method) {
          case "getAll":
            return sharedPreferences;
          case "remove":
            sharedPreferences.remove(args["key"]);
            return true;
          case "clear":
            sharedPreferences.clear();
            return true;
          default:
            // setBool, setString, setInt, etc
            if (call.method.startsWith("set")) {
              sharedPreferences[args["key"] as String] =
                  args["value"] as Object;
              return true;
            }

            return null;
        }
      });
}

/*
 * Show [screen] within an app which matches the real app setup
 */
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  // Tall enough to show every setting without scrolling
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AdaptiveTheme(
      light: ThemeData.light(),
      dark: ThemeData.dark(),
      initial: AdaptiveThemeMode.light,
      builder: (light, dark) => MaterialApp(
        theme: light,
        darkTheme: dark,
        builder: OneContext().builder,
        navigatorKey: OneContext().key,
        localizationsDelegates: [
          I18N.delegate,
          LocaleNamesLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: supported_locales,
        home: screen,
      ),
    ),
  );

  // Localizations are loaded asynchronously, before the screen is built
  await waitUntil(tester, () => find.byWidget(screen).evaluate().isNotEmpty);
}

/*
 * Allow both real async operations (e.g. file and network access)
 * and fake time (e.g. timers, animations) to progress,
 * then rebuild the widget tree.
 *
 * Note: Database operations must be started in the test (fake async) zone,
 * as the preferences database uses short timers between operations.
 * Waiting on them inside tester.runAsync() would block forever.
 */
Future<void> step(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
  await tester.pump(const Duration(milliseconds: 10));
}

// Wait until [done] returns true
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() done, {
  String? reason,
}) async {
  final Stopwatch timer = Stopwatch()..start();

  while (!done() && timer.elapsed < const Duration(seconds: 10)) {
    await step(tester);
  }

  expect(done(), isTrue, reason: reason);
}

// Wait for [future] (started in the test zone) to complete
Future<T> settle<T>(WidgetTester tester, Future<T> future) async {
  bool complete = false;
  T? value;
  Object? error;

  future.then(
    (T result) {
      value = result;
      complete = true;
    },
    onError: (Object e) {
      error = e;
      complete = true;
    },
  );

  await waitUntil(tester, () => complete);

  if (error != null) {
    throw error!;
  }

  return value as T;
}

/*
 * Connect to the test server (see setup.dart) from within a widget test.
 *
 * Call disconnectInWidgetTest() at the end of the test,
 * to stop the timers started by the connection.
 */
Future<void> connectInWidgetTest(WidgetTester tester) async {
  await settle(tester, connectToTestServer());

  expect(InvenTreeAPI().isConnected(), isTrue);
}

Future<void> disconnectInWidgetTest(WidgetTester tester) async {
  InvenTreeAPI().disconnectFromServer();

  // Allow any idle HTTP connections to expire
  await tester.pump(const Duration(seconds: 16));
}

// Return true if every displayed screen has finished loading
bool allLoaded(WidgetTester tester) => tester
    .stateList<State>(find.byWidgetPredicate((w) => w is StatefulWidget))
    .whereType<RefreshableState<StatefulWidget>>()
    .every((state) => state.loaded);

// Wait for screens to load, and any other outstanding requests to complete
Future<void> idle(WidgetTester tester) async {
  await waitUntil(tester, () => allLoaded(tester), reason: "screens loaded");

  for (int i = 0; i < 20; i++) {
    await step(tester);
  }

  // Complete any page transitions
  await tester.pump(const Duration(milliseconds: 500));
}

/*
 * Open each (visible) link to another screen, then return to [screen].
 *
 * By default, links are the "chevron" icons displayed by LinkIcon().
 * [beforeEach] is called before each link is found (e.g. to open a menu).
 */
Future<void> followLinks(
  WidgetTester tester,
  Widget screen, {
  Finder Function()? links,
  Future<void> Function()? beforeEach,
}) async {
  links ??= () => find.byIcon(TablerIcons.chevron_right).hitTestable();

  bool isCurrent() =>
      ModalRoute.of(
        tester.element(find.byWidget(screen, skipOffstage: false)),
      )?.isCurrent ??
      false;

  await beforeEach?.call();

  final int count = links().evaluate().length;

  for (int idx = 0; idx < count; idx++) {
    if (idx > 0) {
      await beforeEach?.call();
    }

    // The screen may have changed (e.g. reloaded)
    if (idx >= links().evaluate().length) {
      break;
    }

    await tester.tap(links().at(idx));
    await idle(tester);

    // Return to the original screen
    while (!isCurrent()) {
      OneContext().key.currentState!.pop();
      await idle(tester);
    }
  }
}

// Optional information, which is hidden by default
const Map<String, bool> displaySettings = {
  INV_SHOW_PK: true,
  INV_SHOW_HISTORY: true,
};

/*
 * Connect to the test server, run [body], then disconnect.
 *
 * If [displayAll] is set, optional information is displayed (more code paths)
 */
Future<void> withServer(
  WidgetTester tester,
  Future<void> Function() body, {
  bool displayAll = false,
}) async {
  await connectInWidgetTest(tester);

  if (displayAll) {
    await settle(
      tester,
      Future.wait([
        for (final entry in displaySettings.entries)
          InvenTreeSettingsManager().setValue(entry.key, entry.value),
      ]),
    );
  }

  try {
    await body();
  } finally {
    if (displayAll) {
      await settle(
        tester,
        Future.wait([
          for (final key in displaySettings.keys)
            InvenTreeSettingsManager().removeValue(key),
        ]),
      );
    }

    await disconnectInWidgetTest(tester);
  }
}
