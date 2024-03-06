import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:adaptive_theme/adaptive_theme.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_localized_locales/flutter_localized_locales.dart";
import "package:one_context/one_context.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sentry_flutter/sentry_flutter.dart";

import "package:inventree/dsn.dart";
import "package:inventree/preferences.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/l10n/supported_locales.dart";
import "package:inventree/settings/release.dart";
import "package:inventree/widget/home.dart";


Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  await runZonedGuarded<Future<void>>(() async {

    PackageInfo info = await PackageInfo.fromPlatform();
    String pkg = info.packageName;
    String version = info.version;
    String build = info.buildNumber;

    String release = "${pkg}@${version}:${build}";

    if (SENTRY_DSN_KEY.isNotEmpty) {
      await Sentry.init((options) {
        options.dsn = SENTRY_DSN_KEY;
        options.release = release;
        options.environment = isInDebugMode() ? "debug" : "release";
        options.diagnosticLevel = SentryLevel.debug;
        options.attachStacktrace = true;
      });
    }

    // Pass any flutter errors off to the Sentry reporting context!
    FlutterError.onError = (FlutterErrorDetails details) async {

      // Ensure that the error gets reported to sentry!
      await sentryReportError(
        "FlutterError.onError",
        details.exception, details.stack,
        context: {
          "context": details.context.toString(),
          "summary": details.summary.toString(),
          "library": details.library ?? "null",
        }
      );
    };

    final int orientation = await InvenTreeSettingsManager().getValue(INV_SCREEN_ORIENTATION, SCREEN_ORIENTATION_SYSTEM) as int;

    List<DeviceOrientation> orientations = [];

    switch (orientation) {
      case SCREEN_ORIENTATION_PORTRAIT:
        orientations.add(DeviceOrientation.portraitUp);
        break;
      case SCREEN_ORIENTATION_LANDSCAPE:
        orientations.add(DeviceOrientation.landscapeLeft);
        break;
      default:
        orientations.add(DeviceOrientation.portraitUp);
        orientations.add(DeviceOrientation.landscapeLeft);
        orientations.add(DeviceOrientation.landscapeRight);
        break;
    }

    SystemChrome.setPreferredOrientations(orientations).then((_) {
      runApp(
        InvenTreeApp(savedThemeMode)
      );
    });

  }, (Object error, StackTrace stackTrace) async {
    sentryReportError("main.runZonedGuarded", error, stackTrace);
  });

}

class InvenTreeApp extends StatefulWidget {
  // This widget is the root of your application.

  const InvenTreeApp(this.savedThemeMode);

  final AdaptiveThemeMode? savedThemeMode;

  @override
  InvenTreeAppState createState() => InvenTreeAppState(savedThemeMode);

  static InvenTreeAppState? of(BuildContext context) => context.findAncestorStateOfType<InvenTreeAppState>();

}


class InvenTreeAppState extends State<StatefulWidget> {

  InvenTreeAppState(this.savedThemeMode) : super();

  // Custom _locale (default = null; use system default)
  Locale? _locale;

  final AdaptiveThemeMode? savedThemeMode;

  @override
  void initState() {
    super.initState();

    // Run some async init tasks
    runInitTasks();
  }

  // Run app init routines in the background
  Future<void> runInitTasks() async {

    // Set the app locale (language)
    Locale? locale = await InvenTreeSettingsManager().getSelectedLocale();
    setLocale(locale);

    // Display release notes if this is a new version
    final String version = await InvenTreeSettingsManager().getValue("recentVersion", "") as String;

    final PackageInfo info = await PackageInfo.fromPlatform();
    
    if (version != info.version) {
      // Save latest version to the settings database
      await InvenTreeSettingsManager().setValue("recentVersion", info.version);

      // Load release notes from external file
      String notes = await rootBundle.loadString("assets/release_notes.md");

      // Show the release notes
      OneContext().push(
          MaterialPageRoute(builder: (context) => ReleaseNotesWidget(notes))
      );
    }
  }

  // Update the app locale
  void setLocale(Locale? locale) {
    setState(() {
      _locale = locale;
    });
  }

  Locale? get locale => _locale;

  @override
  Widget build(BuildContext context) {

    return AdaptiveTheme(
      light: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.lightBlue,
        secondaryHeaderColor: Colors.blueGrey
      ),
      dark: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.lightBlue,
        secondaryHeaderColor: Colors.blueGrey,
      ),
      initial: savedThemeMode ?? AdaptiveThemeMode.light,
      builder: (light, dark) =>  MaterialApp(
        theme: light,
        darkTheme: dark,
        debugShowCheckedModeBanner: false,
        builder: OneContext().builder,
        navigatorKey: OneContext().key,
        onGenerateTitle: (BuildContext context) => "InvenTree",
        home: InvenTreeHomePage(),
        localizationsDelegates: [
          I18N.delegate,
          LocaleNamesLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: supported_locales,
        locale: _locale,
      )
    );
  }
}
