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

  void _showParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
  }

  void _showStarredParts(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    // TODO
    // Navigator.push(context, MaterialPageRoute(builder: (context) => StarredPartWidget()));
  }

  void _showStock(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDisplayWidget(null)));
  }

  void _showPurchaseOrders(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;
  }


  void _showSuppliers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().suppliers, {"is_supplier": "true"})));
  }

  void _showManufacturers(BuildContext context) {
    if (!InvenTreeAPI().checkConnection(context)) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyListWidget(L10().manufacturers, {"is_manufacturer": "true"})));
  }

  void _showCustomers(BuildContext context) {
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

  Widget _header(String label) {
    return Card(
      margin: EdgeInsets.symmetric(
        vertical: 1,
        horizontal: 10,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 1
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _grid(List<Widget> children) {
    return GridView.extent(
      maxCrossAxisExtent: 140,
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      children: children,
    );
  }

  Widget _iconButton(String label, IconData icon, {Function()? callback}) {

    return GestureDetector(
      child: Card(
        margin: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              color: COLOR_CLICK,
            ),
            Divider(
              height: 10,
            ),
            Text(
              label,
            ),
          ]
        )
      ),
      onTap: callback,
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
      key: _homeKey,
      appBar: AppBar(
        title: Text(L10().appTitle),
        actions: <Widget>[
          // IconButton(
          //   icon: FaIcon(FontAwesomeIcons.barcode),
          //   tooltip: L10().scanBarcode,
          //   onPressed: () {
          //     _scan(context);
          //   },
          // ),
        ],
      ),
      drawer: new InvenTreeDrawer(context),
      body: ListView(
        physics: ClampingScrollPhysics(),
        shrinkWrap: true,
        children: [
          _grid([
            _iconButton(
                L10().scanBarcode,
                FontAwesomeIcons.barcode,
                callback: () {
                  _scan(context);
                }
            ),
            _iconButton(
                L10().search,
                FontAwesomeIcons.search,
                callback: () {
                  // TODO: Launch "generic" search widget
                }
            ),
            _iconButton(
                L10().parts,
                FontAwesomeIcons.shapes,
                callback: () {
                  _showParts(context);
                }
            ),

              // TODO - Re-add starred parts link
              /*
            Column(
              children: <Widget>[
                IconButton(
                  icon: FaIcon(FontAwesomeIcons.solidStar),
                  onPressed: () {

                  },
                ),
                Text("Starred Parts"),
              ]
            ),
             */

            _iconButton(
                L10().stock,
                FontAwesomeIcons.boxes,
                callback: () {
                  _showStock(context);
                }
            ),
            _iconButton(
                L10().purchaseOrders,
                FontAwesomeIcons.shoppingCart,
                callback: () {
                  _showPurchaseOrders(context);
                }
            ),
            _iconButton(
                L10().suppliers,
                FontAwesomeIcons.building,
                callback: () {
                  _showSuppliers(context);
                }
            ),
            _iconButton(
                L10().manufacturers,
                FontAwesomeIcons.industry,
                callback: () {
                  _showManufacturers(context);
                }
            ),
            _iconButton(
              L10().customers,
              FontAwesomeIcons.userTie,
              callback: () {
                _showCustomers(context);
              }
            ),
              /*
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
              /*
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
       */
            ],
          )
        ]
      ),
    );
  }
}
