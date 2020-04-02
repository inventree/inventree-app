import 'package:InvenTree/widget/category_display.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:preferences/preferences.dart';

import 'settings.dart';
import 'api.dart';
import 'preferences.dart';

import 'package:InvenTree/inventree/part.dart';

void main() async {

  // await PrefService.init(prefix: "inventree_");

  String username = "username";
  String password = "password";
  String server = "http://127.0.0.1:8000";

  InvenTreeAPI().connect(server, username, password);

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
  int _counter = 0;

  // List of parts
  List<InvenTreePart> _parts = List<InvenTreePart>();

  String _filter = '';

  List<InvenTreePart> get parts {

    if (_filter.isNotEmpty) {

      List<InvenTreePart> filtered = List<InvenTreePart>();
      for (var part in _parts) {

        var name = part.name.toLowerCase() + ' ' + part.description.toLowerCase();

        bool match = true;

        for (var txt in _filter.split(' ')) {
          if (!name.contains(txt)) {
            match = false;
            break;
          }
        }

        if (match) {
          filtered.add(part);
        }
      }

      return filtered;
    } else {

      // No filtering
      return _parts;
    }
  }

  _MyHomePageState() : super() {

    // Request list of parts from the server,
    // and display the results when they are received
    InvenTreePart().list(filters: {"search": "0805"}).then((var parts) {
      _parts.clear();

      for (var part in parts) {
        if (part is InvenTreePart) {
          _parts.add(part);
        }

        // Update state!
        setState(() {
        });
      }
    });
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void _login() {
    //Navigator.push(context, MaterialPageRoute(builder: (context) => InvenTreeSettingsWidget()));
  }

  void _showParts() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(-1)));
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
        /*
        leading: IconButton(
          icon: Icon(Icons.menu),
          tooltip: "Menu",
          onPressed: null,
        )
        */
      ),
      drawer: new Drawer(
          child: new ListView(
            children: <Widget>[
              new ListTile(
                leading: new Image.asset("assets/image/icon.png",
                  fit: BoxFit.scaleDown,
                 ),
                  title: new Text("InvenTree"),
              ),
              new Divider(),
              new ListTile(
                title: new Text("Scan"),
              ),
              new ListTile(
                title: new Text("Parts"),
                onTap: _showParts,
              ),
              new ListTile(
                title: new Text("Stock"),
              ),
              new Divider(),
              new ListTile(
                title: new Text("Settings"),
                leading: new Icon(Icons.settings),
                onTap: _login,
              ),
            ],
          )
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                hintText: 'Filter Results',
              ),
              onChanged: (text) {
                setState(() {
                  _filter = text.trim().toLowerCase();
                });
              },
            ),
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.display1,
            ),
            Text(
              'hello world',
            ),
            Expanded(child: ProductList(parts)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
