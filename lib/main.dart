import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/widget/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'dsn.dart';
import 'preferences.dart';

import 'package:sentry/sentry.dart';

// Use the secret app key
final SentryClient _sentry = SentryClient(dsn: SENTRY_DSN_KEY);

bool isInDebugMode() {
  bool inDebugMode = false;

  assert(inDebugMode = true);

  return inDebugMode;
}

Future<void> _reportError(dynamic error, dynamic stackTrace) async {
  // Print the exception to the console.
  print('Caught error: $error');
  if (isInDebugMode()) {
    // Print the full stacktrace in debug mode.
    print(stackTrace);
    return;
  } else {
    // Send the Exception and Stacktrace to Sentry in Production mode.
    _sentry.captureException(
      exception: error,
      stackTrace: stackTrace,
    );

    print("Sending error to sentry.io");
  }
}

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Load login details
  InvenTreePreferences().loadLoginDetails();

  runZoned<Future<void>>(() async {
    runApp(InvenTreeApp());
  }, onError: (error, stackTrace) {
    // Whenever an error occurs, call the `_reportError` function. This sends
    // Dart errors to the dev console or Sentry depending on the environment.
    _reportError(error, stackTrace);
  });

}

class InvenTreeApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => I18N.of(context).appTitle,
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
        const Locale('en', ''), // English, no country code
        const Locale('de', ''),
        const Locale('fr', ''),
        const Locale('it', ''),
      ],
    );
  }
}