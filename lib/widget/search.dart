import "dart:async";

import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/part_list.dart";
import "package:inventree/widget/purchase_order_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/widget/stock_list.dart";
import "package:inventree/widget/category_list.dart";
import "package:inventree/widget/company_list.dart";
import "package:inventree/widget/location_list.dart";


// Widget for performing database-wide search
class SearchWidget extends StatefulWidget {

  SearchWidget(this.hasAppbar);

  final bool hasAppbar;

  @override
  _SearchDisplayState createState() => _SearchDisplayState(hasAppbar);

}

class _SearchDisplayState extends RefreshableState<SearchWidget> {

  _SearchDisplayState(this.hasAppBar) : super();

  final bool hasAppBar;

  @override
  String getAppBarTitle(BuildContext context) => L10().search;

  @override
  AppBar? buildAppBar(BuildContext context) {
    if (hasAppBar) {
      return super.buildAppBar(context);
    } else {
      return null;
    }
  }

  final TextEditingController searchController = TextEditingController();

  Timer? debounceTimer;

  int nPartResults = 0;

  int nCategoryResults = 0;

  int nStockResults = 0;

  int nLocationResults = 0;

  int nSupplierResults = 0;

  int nPurchaseOrderResults = 0;

  // Callback when the text is being edited
  // Incorporates a debounce timer to restrict search frequency
  void onSearchTextChanged(String text, {bool immediate = false}) {

    if (debounceTimer?.isActive ?? false) {
      debounceTimer!.cancel();
    }

    if (immediate) {
      search(text);
    } else {
      debounceTimer = Timer(Duration(milliseconds: 250), () {
        search(text);
      });
    }

  }

  Future<void> search(String term) async {

    if (term.isEmpty) {
      setState(() {
        // Do not search on an empty string
        nPartResults = 0;
        nCategoryResults = 0;
        nStockResults = 0;
        nLocationResults = 0;
        nSupplierResults = 0;
        nPurchaseOrderResults = 0;
      });

      return;
    }

    // Search parts
    InvenTreePart().count(
      searchQuery: term
    ).then((int n) {
      setState(() {
        nPartResults = n;
      });
    });

    // Search part categories
    InvenTreePartCategory().count(
      searchQuery: term,
    ).then((int n) {
      setState(() {
        nCategoryResults = n;
      });
    });

    // Search stock items
    InvenTreeStockItem().count(
      searchQuery: term
    ).then((int n) {
      setState(() {
        nStockResults = n;
      });
    });

    // Search stock locations
    InvenTreeStockLocation().count(
      searchQuery: term
    ).then((int n) {
      setState(() {
        nLocationResults = n;
      });
    });

    // Search suppliers
    InvenTreeCompany().count(
      searchQuery: term,
      filters: {
        "is_supplier": "true",
      },
    ).then((int n) {
      setState(() {
        nSupplierResults = n;
      });
    });

    // Search purchase orders
    InvenTreePurchaseOrder().count(
      searchQuery: term,
      filters: {
        "outstanding": "true"
      }
    ).then((int n) {
      setState(() {
        nPurchaseOrderResults = n;
      });
    });

  }

  List<Widget> _tiles(BuildContext context) {

    List<Widget> tiles = [];

    // Search input
    tiles.add(
      InputDecorator(
        decoration: InputDecoration(
        ),
        child: ListTile(
          title: TextField(
            readOnly: false,
            controller: searchController,
            onChanged: (String text) {
              onSearchTextChanged(text);
            },
          ),
          leading: IconButton(
            icon: FaIcon(FontAwesomeIcons.backspace, color: Colors.red),
            onPressed: () {
              searchController.clear();
              onSearchTextChanged("", immediate: true);
            },
          ),
        )
      )
    );

    String query = searchController.text;

    List<Widget> results = [];

    // Part Results
    if (nPartResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().parts),
          leading: FaIcon(FontAwesomeIcons.shapes),
          trailing: Text("${nPartResults}"),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PartList(
                        {
                          "original_search": query
                        }
                    )
                )
            );
          }
        )
      );
    }

    // Part Category Results
    if (nCategoryResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().partCategories),
          leading: FaIcon(FontAwesomeIcons.sitemap),
          trailing: Text("${nCategoryResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PartCategoryList(
                  {
                    "original_search": query
                  }
                )
              )
            );
          },
        )
      );
    }

    // Stock Item Results
    if (nStockResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().stockItems),
          leading: FaIcon(FontAwesomeIcons.boxes),
          trailing: Text("${nStockResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockItemList(
                  {
                    "original_search": query,
                  }
                )
              )
            );
          },
        )
      );
    }

    // Stock location results
    if (nLocationResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().stockLocations),
          leading: FaIcon(FontAwesomeIcons.mapMarkerAlt),
          trailing: Text("${nLocationResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockLocationList(
                  {
                    "original_search": query
                  }
                )
              )
            );
          },
        )
      );
    }

    // Suppliers
    if (nSupplierResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().suppliers),
          leading: FaIcon(FontAwesomeIcons.building),
          trailing: Text("${nSupplierResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyListWidget(
                  L10().suppliers,
                  {
                    "is_supplier": "true",
                    "original_search": query
                  }
                )
              )
            );
          },
        )
      );
    }

    // Purchase orders
    if (nPurchaseOrderResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().purchaseOrders),
          leading: FaIcon(FontAwesomeIcons.shoppingCart),
          trailing: Text("${nPurchaseOrderResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseOrderListWidget(
                  filters: {
                    "original_search": query
                  }
                )
              )
            );
          },
        )
      );
    }

    if (results.isEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().queryNoResults),
          leading: FaIcon(FontAwesomeIcons.search),
        )
      );
    } else {
      for (Widget result in results) {
        tiles.add(result);
      }
    }

    return tiles;

  }

  @override
  Widget getBody(BuildContext context) {
    return Center(
      child: ListView(
        children: ListTile.divideTiles(
          context: context,
          tiles: _tiles(context),
        ).toList()
      )
    );
  }
}
