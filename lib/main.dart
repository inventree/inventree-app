import 'dart:async';

import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/company_list.dart';
import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/search.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'barcode.dart';

import 'api.dart';
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
      title: 'InvenTree',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        secondaryHeaderColor: Colors.blueGrey,
      ),
      home: MyHomePage(title: 'InvenTree'),
    );
  }
}


class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);


  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  _MyHomePageState() : super() {
    _checkServerConnection();
  }

  String _serverAddress = "";

  String _serverStatus = "Connecting to server";

  String _serverMessage = "";

  bool _serverConnection = false;

  FaIcon _serverIcon = new FaIcon(FontAwesomeIcons.spinner);

  Color _serverStatusColor = Color.fromARGB(255, 50, 50, 250);
  
  void onConnectSuccess(String msg) {
    _serverConnection = true;
    _serverMessage = msg;
    _serverStatus = "Connected to $_serverAddress";
    _serverStatusColor = Color.fromARGB(255, 50, 250, 50);
    _serverIcon = new FaIcon(FontAwesomeIcons.checkCircle, color: _serverStatusColor);

    setState(() {});
  }
  
  void onConnectFailure(String msg) {
    _serverConnection = false;
    _serverMessage = msg;
    _serverStatus = "Could not connect to $_serverAddress";
    _serverStatusColor = Color.fromARGB(255, 250, 50, 50);
    _serverIcon = new FaIcon(FontAwesomeIcons.timesCircle, color: _serverStatusColor);

    setState(() {});
  }

  /*
   * Test the server connection
   */
  void _checkServerConnection() async {

    var prefs = await SharedPreferences.getInstance();

    _serverAddress = prefs.getString("server");

    // Reset the connection status variables
    _serverStatus = "Connecting to server";
    _serverMessage = "";
    _serverConnection = false;
    _serverIcon = new FaIcon(FontAwesomeIcons.spinner);
    _serverStatusColor = Color.fromARGB(255, 50, 50, 250);

    InvenTreeAPI().connect().then((bool result) {

      if (result) {
        onConnectSuccess("");
      } else {
        onConnectFailure("Could not connect to server");
      }

    });

    // Update widget state
    setState(() {});
  }

  void _search() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => SearchWidget()));

  }

  void _scan() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    scanQrCode(context);
  }

  void _parts() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  void _stock() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
  }

  void _suppliers() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => SupplierListWidget()));
  }

  void _manufacturers() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => ManufacturerListWidget()));
  }

  void _customers() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerListWidget()));
  }

  void _unsupported() {
    showDialog(
      context:  context,
      child: new SimpleDialog(
        title: new Text("Unsupported"),
        children: <Widget>[
          ListTile(
            title: Text("This feature is not yet supported"),
            subtitle: Text("It will be supported in an upcoming release"),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: <Widget>[
          /*
          IconButton(
            icon: FaIcon(FontAwesomeIcons.search),
            tooltip: 'Search',
            onPressed: _search,
          ),
           */
        ],
      ),
      drawer: new InvenTreeDrawer(context),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: (<Widget>[
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                /*
                Column(
                  children: <Widget>[

                   IconButton(
                     icon: new FaIcon(FontAwesomeIcons.search),
                     tooltip: 'Search',
                     onPressed: _search,
                   ),
                   Text("Search"),
                  ],
                ),
                */
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.barcode),
                      tooltip: 'Scan Barcode',
                      onPressed: _scan,
                    ),
                    Text("Scan Barcode"),
                  ],
                ),
              ],
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.shapes),
                      tooltip: 'Parts',
                      onPressed: _parts,
                    ),
                    Text("Parts"),
                  ],
                ),
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.boxes),
                      tooltip: 'Stock',
                      onPressed: _stock,
                    ),
                    Text('Stock'),
                  ],
                ),
              ],
            ),
            Spacer(),
            // TODO - Re-add these when the features actually do something..
            /*
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.building),
                      tooltip: "Suppliers",
                        onPressed: _suppliers,
                    ),
                    Text("Suppliers"),
                  ],
                ),
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.industry),
                      tooltip: "Manufacturers",
                      onPressed: _manufacturers,
                    ),
                    Text("Manufacturers")
                  ],
                ),
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.userTie),
                      tooltip: "Customers",
                      onPressed: _customers,
                    ),
                    Text("Customers"),
                  ]
                )
              ],
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.tools),
                      tooltip: "Build",
                      onPressed: _unsupported,
                    ),
                    Text("Build"),
                  ],
                ),
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.shoppingCart),
                      tooltip: "Order",
                      onPressed: _unsupported,
                    ),
                    Text("Order"),
                  ]
                ),
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.truck),
                      tooltip: "Ship",
                      onPressed: _unsupported,
                    ),
                    Text("Ship"),
                  ]
                )
              ],
            ),
            Spacer(),
            */
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: ListTile(
                    title: Text("$_serverStatus",
                      style: TextStyle(color: _serverStatusColor),
                      ),
                    subtitle: Text("$_serverMessage",
                      style: TextStyle(color: _serverStatusColor),
                    ),
                    leading: _serverIcon,
                    onTap: () {
                      if (!_serverConnection) {
                        _checkServerConnection();
                      }
                    },
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
