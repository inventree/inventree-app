import 'dart:async';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/company_list.dart';
import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'barcode.dart';

import 'dart:convert';

import 'settings/settings.dart';
import 'api.dart';
import 'preferences.dart';

import 'package:InvenTree/inventree/part.dart';

void main() async {

  // await PrefService.init(prefix: "inventree_");

  WidgetsFlutterBinding.ensureInitialized();

  // Load login details
  InvenTreePreferences().loadLoginDetails();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InvenTree',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.lightGreen,
      ),
      home: MyHomePage(title: 'InvenTree'),
    );
  }
}


class ProductList extends StatelessWidget {
  final List<InvenTreePart> _parts;

  ProductList(this._parts);

  Widget _buildPart(BuildContext context, int index) {
    InvenTreePart part;

    if (index < _parts.length) {
      part = _parts[index];
    }

    return Card(
        child: Column(
            children: <Widget>[
              Text('${part.name} - ${part.description}'),
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemBuilder: _buildPart, itemCount: _parts.length);
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

    }).catchError((e) {

      String fault = "Connection error";

      _serverConnection = false;
      _serverStatusColor = Color.fromARGB(255, 250, 50, 50);

      _serverStatus = "Error connecting to $_serverAddress";

      if (e is TimeoutException) {
        fault = "Timeout: No response from server";
      } else {
        fault = e.toString();
      }

      onConnectFailure(fault);
    });

    // Update widget state
    setState(() {});
  }

  void _search() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    // TODO
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

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget()));
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
          IconButton(
            icon: Icon(Icons.search),
            tooltip: 'Search',
            onPressed: null,
          ),
        ],
      ),
      drawer: new InvenTreeDrawer(context),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                   IconButton(
                     icon: new FaIcon(FontAwesomeIcons.search),
                     tooltip: 'Search',
                     onPressed: _unsupported,
                   ),
                   Text("Search"),
                  ],
                ),
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
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.industry),
                      tooltip: 'Suppliers',
                      onPressed: _suppliers,
                    ),
                    Text("Suppliers"),
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
          ],
        ),
      ),
    );
  }
}
