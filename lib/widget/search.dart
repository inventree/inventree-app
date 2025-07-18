import "dart:async";
import "package:async/async.dart";
import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/part/part_list.dart";
import "package:inventree/widget/order/purchase_order_list.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/stock/stock_list.dart";
import "package:inventree/widget/part/category_list.dart";
import "package:inventree/widget/stock/location_list.dart";
import "package:inventree/widget/order/sales_order_list.dart";
import "package:inventree/widget/company/company_list.dart";
import "package:inventree/widget/company/supplier_part_list.dart";

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

  CancelableOperation<void>? _search_query;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  String getAppBarTitle() => L10().search;

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
  int nPurchaseOrderResults = 0;
  int nSalesOrderResults = 0;
  int nSupplierPartResults = 0;
  int nManufacturerPartResults = 0;
  int nCompanyResults = 0;
  int nCustomerResults = 0;
  int nManufacturerResults = 0;
  int nSupplierResults = 0;

  void resetSearchResults() {
    if (mounted) {
      setState(() {
        nPendingSearches = 0;

        nPartResults = 0;
        nCategoryResults = 0;
        nStockResults = 0;
        nLocationResults = 0;
        nPurchaseOrderResults = 0;
        nSalesOrderResults = 0;
        nSupplierPartResults = 0;
        nManufacturerPartResults = 0;
        nCompanyResults = 0;
        nCustomerResults = 0;
        nManufacturerResults = 0;
        nSupplierResults = 0;
      });
    }
  }

  // Callback when the text is being edited
  // Incorporates a debounce timer to restrict search frequency
  void onSearchTextChanged(String text, {bool immediate = false}) {
    if (debounceTimer?.isActive ?? false) {
      debounceTimer!.cancel();
    }

    if (immediate) {
      search(text);
    } else {
      debounceTimer = Timer(Duration(milliseconds: 300), () {
        search(text);
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
  int getSearchResultCount(Map<String, dynamic> results, String key) {
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

  // Actually perform the search query
  Future<void> _perform_search(Map<String, dynamic> body) async {
    InvenTreeAPI().post("search/", body: body, expectedStatusCode: 200).then((
      APIResponse response,
    ) {
      String searchTerm = (body["search"] ?? "").toString();

      // Only update if the results correspond to the current search term
      if (searchTerm == searchController.text && mounted) {
        decrementPendingSearches();

        Map<String, dynamic> results = {};

        if (response.isValid() && response.data is Map<String, dynamic>) {
          results = response.data as Map<String, dynamic>;

          setState(() {
            nPartResults = getSearchResultCount(
              results,
              InvenTreePart.MODEL_TYPE,
            );
            nCategoryResults = getSearchResultCount(
              results,
              InvenTreePartCategory.MODEL_TYPE,
            );
            nStockResults = getSearchResultCount(
              results,
              InvenTreeStockItem.MODEL_TYPE,
            );
            nLocationResults = getSearchResultCount(
              results,
              InvenTreeStockLocation.MODEL_TYPE,
            );
            nPurchaseOrderResults = getSearchResultCount(
              results,
              InvenTreePurchaseOrder.MODEL_TYPE,
            );
            nSalesOrderResults = getSearchResultCount(
              results,
              InvenTreeSalesOrder.MODEL_TYPE,
            );
            nSupplierPartResults = getSearchResultCount(
              results,
              InvenTreeSupplierPart.MODEL_TYPE,
            );
            nManufacturerPartResults = getSearchResultCount(
              results,
              InvenTreeManufacturerPart.MODEL_TYPE,
            );
            nCompanyResults = getSearchResultCount(
              results,
              InvenTreeCompany.MODEL_TYPE,
            );

            // Special case for company search results
            nCustomerResults = getSearchResultCount(results, "customer");
            nManufacturerResults = getSearchResultCount(
              results,
              "manufacturer",
            );
            nSupplierResults = getSearchResultCount(results, "supplier");
          });
        } else {
          resetSearchResults();
        }
      }
    });
  }

  /*
   * Callback when the search input is changed
   */
  Future<void> search(String term) async {
    var api = InvenTreeAPI();

    if (!mounted) {
      return;
    }

    resetSearchResults();

    // Cancel the previous search query (if in progress)
    if (_search_query != null) {
      if (!_search_query!.isCanceled) {
        _search_query!.cancel();
      }
    }

    _search_query = null;

    if (term.isEmpty) {
      return;
    }

    // Consolidated search allows us to perform *all* searches in a single query
    if (api.supportsConsolidatedSearch) {
      Map<String, dynamic> body = {
        "limit": 1,
        "search": term,

        InvenTreePart.MODEL_TYPE: {},
        InvenTreePartCategory.MODEL_TYPE: {},
        InvenTreeStockItem.MODEL_TYPE: {},
        InvenTreeStockLocation.MODEL_TYPE: {},
        InvenTreePurchaseOrder.MODEL_TYPE: {},
        InvenTreeSalesOrder.MODEL_TYPE: {},
        InvenTreeSupplierPart.MODEL_TYPE: {},
        InvenTreeManufacturerPart.MODEL_TYPE: {},
      };

      if (api.supportsSplitCompanySearch) {
        body["supplier"] = {};
        body["manufacturer"] = {};
        body["customer"] = {};
      } else {
        // All "company" results are returned in a single query
        body[InvenTreeCompany.MODEL_TYPE] = {};
      }

      if (body.isNotEmpty) {
        if (mounted) {
          setState(() {
            nPendingSearches = 1;
          });

          _search_query = CancelableOperation.fromFuture(_perform_search(body));
        }
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
    if (InvenTreePart().canView) {
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
    if (InvenTreePartCategory().canView) {
      nPendingSearches++;
      InvenTreePartCategory().count(searchQuery: term).then((int n) {
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
    if (InvenTreeStockItem().canView) {
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
    if (InvenTreeStockLocation().canView) {
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
    if (InvenTreePurchaseOrder().canView) {
      nPendingSearches++;
      InvenTreePurchaseOrder()
          .count(searchQuery: term, filters: {"outstanding": "true"})
          .then((int n) {
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

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Search input
    tiles.add(
      ListTile(
        title: TextFormField(
          decoration: InputDecoration(hintText: L10().queryEmpty),
          key: _formKey,
          readOnly: false,
          autofocus: true,
          autocorrect: false,
          controller: searchController,
          onChanged: (String text) {
            onSearchTextChanged(text);
          },
          onFieldSubmitted: (String text) {},
        ),
        trailing: GestureDetector(
          child: Icon(
            searchController.text.isEmpty
                ? TablerIcons.search
                : TablerIcons.backspace,
            color: searchController.text.isEmpty ? COLOR_ACTION : COLOR_DANGER,
          ),
          onTap: () {
            searchController.clear();
            onSearchTextChanged("", immediate: true);
          },
        ),
      ),
    );

    String query = searchController.text;

    List<Widget> results = [];

    // Part Results
    if (nPartResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().parts),
          leading: Icon(TablerIcons.box),
          trailing: Text("${nPartResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PartList({"original_search": query}),
              ),
            );
          },
        ),
      );
    }

    // Part Category Results
    if (nCategoryResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().partCategories),
          leading: Icon(TablerIcons.sitemap),
          trailing: Text("${nCategoryResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PartCategoryList({"original_search": query}),
              ),
            );
          },
        ),
      );
    }

    // Stock Item Results
    if (nStockResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().stockItems),
          leading: Icon(TablerIcons.package),
          trailing: Text("${nStockResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockItemList({"original_search": query}),
              ),
            );
          },
        ),
      );
    }

    // Stock location results
    if (nLocationResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().stockLocations),
          leading: Icon(TablerIcons.location),
          trailing: Text("${nLocationResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    StockLocationList({"original_search": query}),
              ),
            );
          },
        ),
      );
    }

    // Purchase orders
    if (nPurchaseOrderResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().purchaseOrders),
          leading: Icon(TablerIcons.shopping_cart),
          trailing: Text("${nPurchaseOrderResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseOrderListWidget(
                  filters: {"original_search": query},
                ),
              ),
            );
          },
        ),
      );
    }

    // Sales orders
    if (nSalesOrderResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().salesOrders),
          leading: Icon(TablerIcons.shopping_cart),
          trailing: Text("${nSalesOrderResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SalesOrderListWidget(filters: {"original_search": query}),
              ),
            );
          },
        ),
      );
    }

    // Company results
    if (nCompanyResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().companies),
          leading: Icon(TablerIcons.building),
          trailing: Text("${nCompanyResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyListWidget(L10().companies, {
                  "original_search": query,
                }),
              ),
            );
          },
        ),
      );
    }

    // Customer results
    if (nCustomerResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().customers),
          leading: Icon(TablerIcons.building_store),
          trailing: Text("${nCustomerResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyListWidget(L10().customers, {
                  "original_search": query,
                  "is_customer": "true",
                }),
              ),
            );
          },
        ),
      );
    }

    // Manufacturer results
    if (nManufacturerResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().manufacturers),
          leading: Icon(TablerIcons.building_factory_2),
          trailing: Text("${nManufacturerResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyListWidget(L10().manufacturers, {
                  "original_search": query,
                  "is_manufacturer": "true",
                }),
              ),
            );
          },
        ),
      );
    }

    // Supplier results
    if (nSupplierResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().suppliers),
          leading: Icon(TablerIcons.building_store),
          trailing: Text("${nSupplierResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyListWidget(L10().suppliers, {
                  "original_search": query,
                  "is_supplier": "true",
                }),
              ),
            );
          },
        ),
      );
    }

    // Supplier part results
    if (nSupplierPartResults > 0) {
      results.add(
        ListTile(
          title: Text(L10().supplierParts),
          leading: Icon(TablerIcons.box),
          trailing: Text("${nSupplierPartResults}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SupplierPartList({"original_search": query}),
              ),
            );
          },
        ),
      );
    }

    if (isSearching()) {
      tiles.add(
        ListTile(
          title: Text(L10().searching),
          leading: Icon(TablerIcons.search),
          trailing: CircularProgressIndicator(),
        ),
      );
    }

    if (!isSearching() && results.isEmpty && searchController.text.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(
            L10().queryNoResults,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          leading: Icon(TablerIcons.zoom_cancel),
        ),
      );
    } else {
      for (Widget result in results) {
        tiles.add(result);
      }
    }

    return tiles;
  }
}
