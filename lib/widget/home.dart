import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:InvenTree/barcode.dart';
import 'package:InvenTree/api.dart';

import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/company_list.dart';
import 'package:InvenTree/widget/location_display.dart';
import 'package:InvenTree/widget/search.dart';
import 'package:InvenTree/widget/drawer.dart';

class InvenTreeHomePage extends StatefulWidget {
  InvenTreeHomePage({Key key}) : super(key: key);

  @override
  _InvenTreeHomePageState createState() => _InvenTreeHomePageState();
}

class _InvenTreeHomePageState extends State<InvenTreeHomePage> {

  _InvenTreeHomePageState() : super() {
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
        title: Text(I18N.of(context).appTitle),
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
