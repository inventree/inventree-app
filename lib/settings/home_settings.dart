
import "package:flutter/material.dart";

import "package:inventree/l10.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/preferences.dart";

class HomeScreenSettingsWidget extends StatefulWidget {
  @override
  _HomeScreenSettingsState createState() => _HomeScreenSettingsState();
}

class _HomeScreenSettingsState extends State<HomeScreenSettingsWidget> {

  _HomeScreenSettingsState();

  final GlobalKey<_HomeScreenSettingsState> _settingsKey = GlobalKey<_HomeScreenSettingsState>();

  // Home screen settings
  bool homeShowSubscribed = true;
  bool homeShowPo = true;
  bool homeShowSuppliers = true;
  bool homeShowManufacturers = true;
  bool homeShowCustomers = true;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future <void> loadSettings() async {

    // Load initial settings

    homeShowSubscribed = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SUBSCRIBED, true) as bool;
    homeShowPo = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_PO, true) as bool;
    homeShowManufacturers = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_MANUFACTURERS, true) as bool;
    homeShowCustomers = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_CUSTOMERS, true) as bool;
    homeShowSuppliers = await InvenTreeSettingsManager().getValue(INV_HOME_SHOW_SUPPLIERS, true) as bool;

    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        key: _settingsKey,
        appBar: AppBar(
          title: Text(L10().homeScreen),
        ),
        body: Container(
            child: ListView(
                children: [
                  ListTile(
                      title: Text(L10().homeShowSubscribed),
                      subtitle: Text(L10().homeShowSubscribedDescription),
                      leading: FaIcon(FontAwesomeIcons.bell),
                      trailing: Switch(
                        value: homeShowSubscribed,
                        onChanged: (bool value) {
                          InvenTreeSettingsManager().setValue(INV_HOME_SHOW_SUBSCRIBED, value);
                          setState(() {
                            homeShowSubscribed = value;
                          });
                        },
                      )
                  ),
                  ListTile(
                    title: Text(L10().homeShowPo),
                    subtitle: Text(L10().homeShowPoDescription),
                    leading: FaIcon(FontAwesomeIcons.cartShopping),
                    trailing: Switch(
                      value: homeShowPo,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_HOME_SHOW_PO, value);
                        setState(() {
                          homeShowPo = value;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(L10().homeShowSuppliers),
                    subtitle: Text(L10().homeShowSuppliersDescription),
                    leading: FaIcon(FontAwesomeIcons.building),
                    trailing: Switch(
                      value: homeShowSuppliers,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_HOME_SHOW_SUPPLIERS, value);
                        setState(() {
                          homeShowSuppliers = value;
                        });
                      },
                    ),
                  ),
                  // TODO: When these features are improved, add them back in!
                  // Currently, the company display does not provide any value
                  /*
                  ListTile(
                    title: Text(L10().homeShowManufacturers),
                    subtitle: Text(L10().homeShowManufacturersDescription),
                    leading: FaIcon(FontAwesomeIcons.industry),
                    trailing: Switch(
                      value: homeShowManufacturers,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_HOME_SHOW_MANUFACTURERS, value);
                        setState(() {
                          homeShowManufacturers = value;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(L10().homeShowCustomers),
                    subtitle: Text(L10().homeShowCustomersDescription),
                    leading: FaIcon(FontAwesomeIcons.userTie),
                    trailing: Switch(
                      value: homeShowCustomers,
                      onChanged: (bool value) {
                        InvenTreeSettingsManager().setValue(INV_HOME_SHOW_CUSTOMERS, value);
                        setState(() {
                          homeShowCustomers = value;
                        });
                      },
                    ),
                  ),
                   */
                ]
            )
        )
    );
  }
}