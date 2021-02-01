
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/inventree/stock.dart';


class SearchWidget extends StatefulWidget {

  @override
  _SearchState createState() => _SearchState();
}


class _SearchState extends RefreshableState<SearchWidget> {

  String _searchText = "";

  List<InvenTreePart> _parts = List<InvenTreePart>();
  List<InvenTreeStockItem> _stockItems = List<InvenTreeStockItem>();

  @override
  String getAppBarTitle(BuildContext context) => I18N.of(context).search;

  Future<void> _search(BuildContext context) {
    print("Search: $_searchText}");

    // Ignore if the search text is empty
    if (_searchText.isNotEmpty) {

      // Search for parts
      InvenTreePart().list(context, filters: {"search": _searchText}).then((var parts) {
        setState(() {
          _parts.clear();
          for (var part in parts) {
            if (part is InvenTreePart) {
              _parts.add(part);
            }
          }

          print("Matched ${_parts.length} parts");
        });
      });

      // Search for stock items
      InvenTreeStockItem().list(context, filters: {"search": _searchText}).then((var items) {
        setState(() {
          _stockItems.clear();
          for (var item in items) {
            if (item is InvenTreeStockItem) {
              _stockItems.add(item);
            }
          }

          print("Matched ${_stockItems.length} stock items");
        });
      });
    }
  }

  @override
  Future<void> request(BuildContext context) async {
    _search(context);
  }

  @override
  Widget getBody(BuildContext context) {

    return Center(
      child: ListView(
        children: <Widget>[
          TextField(
            decoration: InputDecoration(
              hintText: I18N.of(context).search,
            ),
            onChanged: (String text) {
              _searchText = text;
            }
          ),
          RaisedButton(
            child: Text(I18N.of(context).search),
            onPressed: () {
              _search(context);
            },
          ),
        ]
      )
    );
  }
}