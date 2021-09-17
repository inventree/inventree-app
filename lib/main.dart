import 'dart:async';

import 'package:inventree/inventree/sentry.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:inventree/widget/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:one_context/one_context.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dsn.dart';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';


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
      await sentryReportError(details.exception, details.stack);
    };

    runApp(
      InvenTreeApp()
    );

  }, (Object error, StackTrace stackTrace) async {
    sentryReportError(error, stackTrace);
  });

}

class InvenTreeApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: OneContext().builder,
      navigatorKey: OneContext().key,
      onGenerateTitle: (BuildContext context) => I18N.of(context)!.appTitle,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        secondaryHeaderColor: Colors.blueGrey,
      ),
      home: InvenTreeHomePage(),
      localizationsDelegates: [
        I18N.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('de', ''),   // German
        const Locale('el', ''),   // Greek
        const Locale('en', ''),   // English
        const Locale('es', ''),   // Spanish
        const Locale('fr', ''),   // French
        const Locale('he', ''),   // Hebrew
        const Locale('it', ''),   // Italian
        const Locale('ja', ''),   // Japanese
        const Locale('ko', ''),   // Korean
        const Locale('nl', ''),   // Dutch
        const Locale('no', ''),   // Norwegian
        const Locale('pl', ''),   // Polish
        const Locale('ru', ''),   // Russian
        const Locale('sv', ''),   // Swedish
        const Locale('th', ''),   // Thai
        const Locale('tr', ''),   // Turkish
        const Locale('vi', ''),   // Vietnamese
        const Locale('zh-CN', ''),   // Chinese
      ],

    );
  }
}