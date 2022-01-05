
import "package:flutter/material.dart";
import "package:flutter/cupertino.dart";

import "package:inventree/l10.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/app_settings.dart";

class InvenTreeAppSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeAppSettingsState createState() => _InvenTreeAppSettingsState();
}

class _InvenTreeAppSettingsState extends State<InvenTreeAppSettingsWidget> {

  _InvenTreeAppSettingsState();

  final GlobalKey<_InvenTreeAppSettingsState> _settingsKey = GlobalKey<_InvenTreeAppSettingsState>();

  // Home screen settings
  bool homeShowSubscribed = true;
  bool homeShowPo = true;
  bool homeShowSuppliers = true;
  bool homeShowManufacturers = true;
  bool homeShowCustomers = true;

  // Sound settings
  bool barcodeSounds = true;
  bool serverSounds = true;

  // Part settings
  bool partSubcategory = false;

  // Stock settings
  bool stockSublocation = false;

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

    barcodeSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;
    serverSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_SERVER, true) as bool;

    partSubcategory = await InvenTreeSettingsManager().getValue(INV_PART_SUBCATEGORY, true) as bool;

    stockSublocation = await InvenTreeSettingsManager().getValue(INV_STOCK_SUBLOCATION, true) as bool;

    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      key: _settingsKey,
      appBar: AppBar(
        title: Text(L10().appSettings),
      ),
      body: Container(
        child: ListView(
          children: [
            /* Home Screen Settings */
            ListTile(
              title: Text(
                L10().homeScreen,
                style: TextStyle(fontWeight: FontWeight.bold)
              ),
            ),
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
              leading: FaIcon(FontAwesomeIcons.shoppingCart),
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
            /* Part Settings */
            Divider(height: 3),
            ListTile(
              title: Text(
                L10().parts,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(L10().includeSubcategories),
              subtitle: Text(L10().includeSubcategoriesDetail),
              leading: FaIcon(FontAwesomeIcons.sitemap),
              trailing: Switch(
                value: partSubcategory,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_PART_SUBCATEGORY, value);
                  setState(() {
                    partSubcategory = value;
                  });
                },
              ),
            ),
            /* Stock Settings */
            Divider(height: 3),
            ListTile(
              title: Text(L10().stock,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(L10().includeSublocations),
              subtitle: Text(L10().includeSublocationsDetail),
              leading: FaIcon(FontAwesomeIcons.sitemap),
              trailing: Switch(
                value: stockSublocation,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STOCK_SUBLOCATION, value);
                  setState(() {
                    stockSublocation = value;
                  });
                },
              ),
            ),
            /* Sound Settings */
            Divider(height: 3),
            ListTile(
              title: Text(
                L10().sounds,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.volumeUp),
            ),
            ListTile(
              title: Text(L10().serverError),
              subtitle: Text(L10().soundOnServerError),
              leading: FaIcon(FontAwesomeIcons.server),
              trailing: Switch(
                value: serverSounds,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_SOUNDS_SERVER, value);
                  setState(() {
                    serverSounds = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().barcodeTones),
              subtitle: Text(L10().soundOnBarcodeAction),
              leading: Icon(Icons.qr_code),
              trailing: Switch(
                value: barcodeSounds,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_SOUNDS_BARCODE, value);
                  setState(() {
                    barcodeSounds = value;
                  });
                },
              ),
            ),
            Divider(height: 1),
          ]
        )
      )
    );
  }
}