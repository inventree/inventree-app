import "dart:async";

import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";

import "package:flutter/material.dart";
import "package:flutter_localized_locales/flutter_localized_locales.dart";
import "package:one_context/one_context.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sentry_flutter/sentry_flutter.dart";

import "package:inventree/inventree/sentry.dart";
import "package:inventree/dsn.dart";
import "package:inventree/preferences.dart";
import "package:inventree/widget/home.dart";

// Supported translations are automatically updated
import "package:inventree/l10n/supported_locales.dart";


Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await runZonedGuarded<Future<void>>(() async {

    PackageInfo info = await PackageInfo.fromPlatform();
    String pkg = info.packageName;
    String version = info.version;
    String build = info.buildNumber;

    String release = "${pkg}@${version}:${build}";

    await Sentry.init((options) {
      options.dsn = SENTRY_DSN_KEY;
      options.release = release;
      options.environment = isInDebugMode() ? "debug" : "release";
    });

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

    runApp(
      InvenTreeApp()
    );

  }, (Object error, StackTrace stackTrace) async {
    sentryReportError("main.runZonedGuarded", error, stackTrace);
  });

}

class InvenTreeApp extends StatefulWidget {
  // This widget is the root of your application.

  @override
  InvenTreeAppState createState() => InvenTreeAppState();

}


class InvenTreeAppState extends State<StatefulWidget> {

  // Custom _locale (default = null; use system default)
  Locale? _locale;

  @override
  void initState() {
    super.initState();

    // Load selected locale
    loadDefaultLocale();
  }

  // Load the default app locale
  Future<void> loadDefaultLocale() async {
    Locale? locale = await InvenTreeSettingsManager().getSelectedLocale();
    setLocale(locale);
  }

  // Update the app locale
  void setLocale(Locale? locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: OneContext().builder,
      navigatorKey: OneContext().key,
      onGenerateTitle: (BuildContext context) => "InvenTree",
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        secondaryHeaderColor: Colors.blueGrey,
      ),
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
    );
  }
}