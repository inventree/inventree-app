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

  final _formKey = GlobalKey<FormState>();

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

  /*
   * Decrement the number of pending / outstanding search queries
   */
  void decrementPendingSearches() {
    if (nPendingSearches > 0) {
      nPendingSearches--;
    }
  }

  /*
   * Determine if the search is still running
   */
  bool isSearching() {

    if (searchController.text.isEmpty) {
      return false;
    }

    return nPendingSearches > 0;
  }

  // Individual search result count (for legacy search API)
  int nPendingSearches = 0;
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
   * Return the 'result count' for a particular query from the results map
   * e.g.
   * {
   *     "part": {
   *         "count": 102,
   *     }
   * }
   */
  int getSearchResultCount(Map <String, dynamic> results, String key) {

    dynamic result = results[key];

    if (result == null || result is! Map) {
      return 0;
    }

    dynamic count = result["count"];

    if (count == null || count is! int) {
      return 0;
    }

    return count;
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

      nPendingSearches = 0;
    });

    if (term.isEmpty) {
      return;
    }

    // Consolidated search allows us to perform *all* searches in a single query
    if (api.supportsConsolidatedSearch) {
      Map<String, dynamic> body = {
        "limit": 1,
        "search": term,
      };

      // Part search
      if (api.checkPermission("part", "view")) {
        body["part"] = {};
      }

      // PartCategory search
      if (api.checkPermission("part_category", "view")) {
        body["partcategory"] = {};
      }

      // StockItem search
      if (api.checkPermission("stock", "view")) {
        body["stockitem"] = {
          "in_stock": true,
        };
      }

      // StockLocation search
      if (api.checkPermission("stock_location", "view")) {
        body["stocklocation"] = {};
      }

      // PurchaseOrder search
      if (api.checkPermission("purchase_order", "view")) {
        body["purchaseorder"] = {
          "outstanding": true
        };
      }

      if (body.isNotEmpty) {
        nPendingSearches++;

        api.post(
            "search/",
            body: body,
            expectedStatusCode: 200).then((APIResponse response) {
          decrementPendingSearches();

          Map<String, dynamic> results = {};

          if (response.data is Map<String, dynamic>) {
            results = response.data as Map<String, dynamic>;
          }

          if (mounted) {
            setState(() {
              nPartResults = getSearchResultCount(results, "part");
              nCategoryResults = getSearchResultCount(results, "partcategory");
              nStockResults = getSearchResultCount(results, "stockitem");
              nLocationResults = getSearchResultCount(results, "stocklocation");
              nSupplierResults = 0; //getSearchResultCount(results, "")
              nPurchaseOrderResults = getSearchResultCount(results, "purchaseorder");
            });
          }
        });
      }
    } else {
      legacySearch(term);
    }
  }

  /*
   * Perform "legacy" search (without consolidated search API endpoint
   */
  Future<void> legacySearch(String term) async {

    // Search parts
    if (api.checkPermission("part", "view")) {
      nPendingSearches++;
      InvenTreePart().count(searchQuery: term).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            decrementPendingSearches();
            setState(() {
              nPartResults = n;
            });
          }
        }
      });
    }

    // Search part categories
    if (api.checkPermission("part_category", "view")) {
      nPendingSearches++;
      InvenTreePartCategory().count(searchQuery: term,).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            decrementPendingSearches();
            setState(() {
              nCategoryResults = n;
            });
          }
        }
      });
    }

    // Search stock items
    if (api.checkPermission("stock", "view")) {
      nPendingSearches++;
      InvenTreeStockItem().count(searchQuery: term).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            decrementPendingSearches();
            setState(() {
              nStockResults = n;
            });
          }
        }
      });
    }

    // Search stock locations
    if (api.checkPermission("stock_location", "view")) {
      nPendingSearches++;
      InvenTreeStockLocation().count(searchQuery: term).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            decrementPendingSearches();
            setState(() {
              nLocationResults = n;
            });
          }
        }
      });
    }

    // Search purchase orders
    if (api.checkPermission("purchase_order", "view")) {
     nPendingSearches++;
      InvenTreePurchaseOrder().count(
          searchQuery: term,
          filters: {
            "outstanding": "true"
          }
      ).then((int n) {
        if (term == searchController.text) {
          if (mounted) {
            decrementPendingSearches();
            setState(() {
              nPurchaseOrderResults = n;
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
          key: _formKey,
          readOnly: false,
          autofocus: false,
          autocorrect: false,
          focusNode: _focusNode,
          controller: searchController,
          onChanged: (String text) {
            onSearchTextChanged(text);
            _focusNode.requestFocus();
          },
          onFieldSubmitted: (String text) {
            _focusNode.requestFocus();
          },
        ),
        trailing: GestureDetector(
          child: FaIcon(
            searchController.text.isEmpty ? FontAwesomeIcons.magnifyingGlass : FontAwesomeIcons.deleteLeft,
            color: searchController.text.isEmpty ? COLOR_CLICK : COLOR_DANGER,
          ),
          onTap: () {
            searchController.clear();
            _focusNode.requestFocus();
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
          leading: FaIcon(FontAwesomeIcons.boxesStacked),
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
          leading: FaIcon(FontAwesomeIcons.locationDot),
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
          leading: FaIcon(FontAwesomeIcons.cartShopping),
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
          leading: FaIcon(FontAwesomeIcons.magnifyingGlass),
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
          leading: FaIcon(FontAwesomeIcons.magnifyingGlassMinus),
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
