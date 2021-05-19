import 'dart:async';
import 'dart:io';

import 'package:InvenTree/inventree/sentry.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'file:///C:/inventree-app/lib/l10.dart';

import 'package:InvenTree/widget/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:one_context/one_context.dart';

import 'dsn.dart';

import 'package:sentry_flutter/sentry_flutter.dart';


void main() async {


  await Sentry.init((options) {
      options.dsn = SENTRY_DSN_KEY;
    },
    //appRunner: () => runApp(InvenTreeApp())
  );

  await runZonedGuarded<Future<void>>(() async {

  WidgetsFlutterBinding.ensureInitialized();

  // This captures errors reported by the Flutter framework.
  FlutterError.onError = (FlutterErrorDetails details) async {
    if (isInDebugMode()) {
      // In development mode simply print to console.
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In production mode report to the application zone to report to
      // Sentry.
      Zone.current.handleUncaughtError(details.exception, details.stack);
    }
  };

  runApp(InvenTreeApp());

  }, (Object error, StackTrace stackTrace) {
    sentryReportError(error, stackTrace);
  });

}

class InvenTreeApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      builder: OneContext().builder,
      navigatorKey: OneContext().key,
      onGenerateTitle: (BuildContext context) => L10().appTitle,
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
        const Locale('de', ''),
        const Locale('en', ''),
        const Locale('es', ''),
        const Locale('fr', ''),
        const Locale('it', ''),
        const Locale('ja', ''),
        const Locale('pl', ''),
        const Locale('ru', ''),
        const Locale('tr', ''),
        const Locale('zh', ''),
      ],
    );
  }
}