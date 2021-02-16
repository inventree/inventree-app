import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/widget/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:one_context/one_context.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  runApp(InvenTreeApp());
}

class InvenTreeApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      builder: OneContext().builder,
      navigatorKey: OneContext().key,
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