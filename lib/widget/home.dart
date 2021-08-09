import 'package:inventree/app_colors.dart';
import 'package:inventree/user_profile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:inventree/l10.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:inventree/barcode.dart';
import 'package:inventree/api.dart';

import 'package:inventree/settings/login.dart';

import 'package:inventree/widget/category_display.dart';
import 'package:inventree/widget/company_list.dart';
import 'package:inventree/widget/location_display.dart';
import 'package:inventree/widget/search.dart';
import 'package:inventree/widget/spinner.dart';
import 'package:inventree/widget/drawer.dart';

class InvenTreeHomePage extends StatefulWidget {

  InvenTreeHomePage({Key? key}) : super(key: key);

  @override
  _InvenTreeHomePageState createState() => _InvenTreeHomePageState();
}

class _InvenTreeHomePageState extends State<InvenTreeHomePage> {

  final GlobalKey<_InvenTreeHomePageState> _homeKey = GlobalKey<_InvenTreeHomePageState>();

  _InvenTreeHomePageState() : super() {

    // Initially load the profile and attempt server connection
    _loadProfile();
  }

  // Selected user profile
  UserProfile? _profile;

  void _searchParts() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    showSearch(
        context: context,
        delegate: PartSearchDelegate(context)
    );
  }

  void _searchStock() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    showSearch(
        context: context,
        delegate: StockSearchDelegate(context)
    );
  }

  void _scan(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    scanQrCode(context);
  }

  void _parts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  void _stock(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
  }

  void _suppliers() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().suppliers, {"is_supplier": "true"})));
  }

  void _manufacturers() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  void _customers() {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().customers, {"is_customer": "true"})));
  }

  void _selectProfile() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => InvenTreeLoginSettingsWidget())
    ).then((context) {
      // Once we return
      _loadProfile();
    });
  }

  void _loadProfile() async {

    _profile = await UserProfileDBManager().getSelectedProfile();

    // A valid profile was loaded!
    if (_profile != null) {
      if (!InvenTreeAPI().isConnected() && !InvenTreeAPI().isConnecting()) {

        // Attempt server connection
        InvenTreeAPI().connectToServer().then((result) {
          setState(() {});
        });
      }
    }

    setState(() {});
  }

  ListTile _serverTile() {

    // No profile selected
    // Tap to select / create a profile
    if (_profile == null) {
      return ListTile(
        title: Text(L10().profileNotSelected),
        subtitle: Text(L10().profileTapToCreate),
        leading: FaIcon(FontAwesomeIcons.server),
        trailing: FaIcon(
          FontAwesomeIcons.user,
          color: COLOR_DANGER,
        ),
        onTap: () {
          _selectProfile();
        },
      );
    }

    // Profile is selected ...
    if (InvenTreeAPI().isConnecting()) {
      return ListTile(
        title: Text(L10().serverConnecting),
        subtitle: Text("${InvenTreeAPI().baseUrl}"),
        leading: FaIcon(FontAwesomeIcons.server),
        trailing: Spinner(
          icon: FontAwesomeIcons.spinner,
          color: COLOR_PROGRESS,
        ),
        onTap: () {
          _selectProfile();
        }
      );
    } else if (InvenTreeAPI().isConnected()) {
      return ListTile(
        title: Text(L10().serverConnected),
        subtitle: Text("${InvenTreeAPI().baseUrl}"),
        leading: FaIcon(FontAwesomeIcons.server),
        trailing: FaIcon(
          FontAwesomeIcons.checkCircle,
          color: COLOR_SUCCESS
        ),
        onTap: () {
          _selectProfile();
        },
      );
    } else {
      return ListTile(
        title: Text(L10().serverCouldNotConnect),
        subtitle: Text("${_profile!.server}"),
        leading: FaIcon(FontAwesomeIcons.server),
        trailing: FaIcon(
          FontAwesomeIcons.timesCircle,
          color: COLOR_DANGER,
        ),
        onTap: () {
          _selectProfile();
        },
      );
    }
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
      key: _homeKey,
      appBar: AppBar(
        title: Text(L10().appTitle),
        actions: <Widget>[
          /*
          IconButton(
            icon: FaIcon(FontAwesomeIcons.search),
            tooltip: L10().search,
            onPressed: _searchParts,
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
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.barcode),
                      tooltip: L10().scanBarcode,
                      onPressed: () { _scan(context); },
                    ),
                    Text(L10().scanBarcode),
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
                      tooltip: L10().parts,
                      onPressed: () { _parts(context); },
                    ),
                    Text(L10().parts),
                  ],
                ),
                Column(
                  children: <Widget>[

                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.search),
                      tooltip: L10().searchParts,
                      onPressed: _searchParts,
                    ),
                    Text(L10().searchParts),
                  ],
                ),
                // TODO - Re-add starred parts link
                /*
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.solidStar),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => StarredPartWidget()));
                      },
                    ),
                    Text("Starred Parts"),
                  ]
                ),
                 */
              ],
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.boxes),
                      tooltip: L10().stock,
                      onPressed: () { _stock(context); },
                    ),
                    Text(L10().stock),
                  ],
                ),
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: new FaIcon(FontAwesomeIcons.search),
                      tooltip: L10().searchStock,
                      onPressed: _searchStock,
                    ),
                    Text(L10().searchStock),
                  ],
                ),
              ]
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
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: _serverTile(),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
