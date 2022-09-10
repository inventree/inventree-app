import "dart:async";

import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/part_list.dart";
import "package:inventree/widget/purchase_order_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/stock_list.dart";
import "package:inventree/widget/category_list.dart";
import "package:inventree/widget/company_list.dart";
import "package:inventree/widget/location_list.dart";


// Widget for performing database-wide search
class SearchWidget extends StatefulWidget {

  const SearchWidget(this.hasAppbar);

  final bool hasAppbar;

  @override
  _SearchDisplayState createState() => _SearchDisplayState(hasAppbar);

}

class _SearchDisplayState extends RefreshableState<SearchWidget> {

  _SearchDisplayState(this.hasAppBar) : super();

  final bool hasAppBar;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  String getAppBarTitle(BuildContext context) => L10().search;

  @override
  AppBar? buildAppBar(BuildContext context, GlobalKey<ScaffoldState> key) {
    if (hasAppBar) {
      return super.buildAppBar(context, key);
    } else {
      return null;
    }
  }

  final TextEditingController searchController = TextEditingController();

  Timer? debounceTimer;

  bool isSearching() {

    if (searchController.text.isEmpty) {
      return false;
    }

    return nSearchResults < 5;
  }

  int nSearchResults = 0;

  int nPartResults = 0;

  int nCategoryResults = 0;

  int nStockResults = 0;

  int nLocationResults = 0;

  int nSupplierResults = 0;

  int nPurchaseOrderResults = 0;

  late FocusNode _focusNode;

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
        if (!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  /*
   * Initiate multiple search requests to the server.
   * Each request returns at *some point* in the future,
   * by which time the search input may have changed, giving unexpected results.
   *
   * So, each request only causes an update *if* the search term is still the same when it completes
   */
  Future<void> search(String term) async {

    var api = InvenTreeAPI();

    if (!mounted) {
      return;
    }
    
    setState(() {
      // Do not search on an empty string
      nPartResults = 0;
      nCategoryResults = 0;
      nStockResults = 0;
      nLocationResults = 0;
      nSupplierResults = 0;
      nPurchaseOrderResults = 0;

      nSearchResults = 0;
    });

    if (term.isEmpty) {
      return;
    }

    // Search parts
    if (api.checkPermission("part", "view")) {
      InvenTreePart().count(searchQuery: term).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            setState(() {
              nPartResults = n;
              nSearchResults++;
            });
          }
        }
      });
    }

    // Search part categories
    if (api.checkPermission("part_category", "view")) {
      InvenTreePartCategory().count(searchQuery: term,).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            setState(() {
              nCategoryResults = n;
              nSearchResults++;
            });
          }
        }
      });
    }

    // Search stock items
    if (api.checkPermission("stock", "view")) {
      InvenTreeStockItem().count(searchQuery: term).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            setState(() {
              nStockResults = n;
              nSearchResults++;
            });
          }
        }
      });
    }

    // Search stock locations
    if (api.checkPermission("stock_location", "view")) {
      InvenTreeStockLocation().count(searchQuery: term).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            setState(() {
              nLocationResults = n;
              nSearchResults++;
            });
          }
        }
      });
    }

    // TDOO: Re-implement this once display for companies has been fixed
    /*
    // Search suppliers
    InvenTreeCompany().count(searchQuery: term,
      filters: {
        "is_supplier": "true",
      },
    ).then((int n) {
      setState(() {
        nSupplierResults = n;
        nSearchResults++;
      });
    });
     */

    // Search purchase orders
    if (api.checkPermission("purchase_order", "view")) {
      InvenTreePurchaseOrder().count(
          searchQuery: term,
          filters: {
            "outstanding": "true"
          }
      ).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            setState(() {
              nPurchaseOrderResults = n;
              nSearchResults++;
            });
          }
        }
      });
    }
  }

  List<Widget> _tiles(BuildContext context) {

    List<Widget> tiles = [];

    // Search input
    tiles.add(
      ListTile(
        title: TextFormField(
          decoration: InputDecoration(
            hintText: L10().queryEmpty,
          ),
          readOnly: false,
          autofocus: false,
          autocorrect: false,
          focusNode: _focusNode,
          controller: searchController,
          onChanged: (String text) {
            onSearchTextChanged(text);
          },
        ),
        trailing: GestureDetector(
          child: FaIcon(
            searchController.text.isEmpty ? FontAwesomeIcons.search : FontAwesomeIcons.backspace,
            color: searchController.text.isEmpty ? COLOR_CLICK : COLOR_DANGER,
          ),
          onTap: () {
            searchController.clear();
            onSearchTextChanged("", immediate: true);
          },
        ),
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

    if (isSearching()) {
      tiles.add(
        ListTile(
          title: Text(L10().searching),
          leading: FaIcon(FontAwesomeIcons.search),
          trailing: CircularProgressIndicator(),
        )
      );
    }

    if (!isSearching() && results.isEmpty && searchController.text.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(
            L10().queryNoResults,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          leading: FaIcon(FontAwesomeIcons.searchMinus),
        )
      );
    } else {
      for (Widget result in results) {
        tiles.add(result);
      }
    }

    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
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
