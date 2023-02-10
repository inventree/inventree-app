import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:infinite_scroll_pagination/infinite_scroll_pagination.dart";

import "package:inventree/api_form.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/preferences.dart";

import "package:inventree/widget/refreshable_state.dart";


/*
 * Abstract base widget class for rendering a PaginatedSearchState
 */
abstract class PaginatedSearchWidget extends StatefulWidget {

  const PaginatedSearchWidget({this.filters = const {}, this.showSearch = false});

  final Map<String, String> filters;

  final bool showSearch;
}


/*
 * Generic stateful widget for displaying paginated data retrieved via the API
 */
abstract class PaginatedSearchState<T extends PaginatedSearchWidget> extends State<T> with BaseWidgetProperties {

  static const _pageSize = 25;

  // Prefix for storing and loading pagination options
  // Override in implementing class
  String get prefix => "prefix_";

  // Return a map of boolean filtering options available for this list
  // Should be overridden by an implementing subclass
  Map<String, Map<String, dynamic>> get filterOptions => {};

  // Return the boolean value of a particular boolean filter
  Future<bool?> getBooleanFilterValue(String key) async {
    key = "${prefix}bool_${key}";

    Map<String, dynamic> opts = filterOptions[key] ?? {};

    bool? backup;
    dynamic v = opts["default"];

    if (v is bool) {
      backup = v;
    }

    final result = await InvenTreeSettingsManager().getTriState(key, backup);
    return result;
  }

  // Set the boolean value of a particular boolean filter
  Future<void> setBooleanFilterValue(String key, bool? value) async {
    key = "${prefix}bool_${key}";
    await InvenTreeSettingsManager().setValue(key, value);
  }

  // Construct the boolean filter options for this list
  Future<Map<String, String>> constructBooleanFilters() async {

    Map<String, String> f = {};

    for (String k in filterOptions.keys) {
      bool? value = await getBooleanFilterValue(k);

      if (value is bool) {
        f[k] = value ? "true" : "false";
      }
    }

    return f;
  }

  // Return a map of sorting options available for this list
  // Should be overridden by an implementing subclass
  Map<String, String> get orderingOptions => {};

  // Return the selected ordering "field" for this list widget
  Future<String> orderingField() async {
    dynamic field = await InvenTreeSettingsManager().getValue("${prefix}ordering_field", null);

    if (field != null && orderingOptions.containsKey(field.toString())) {
      // A valid ordering field has been found
      return field.toString();
    } else if (orderingOptions.isNotEmpty) {
      // By default, return the first specified key
      return orderingOptions.keys.first;
    } else {
      return "";
    }
  }

  // Return the selected ordering "order" ("+" or "-") for this list widget
  Future<String> orderingOrder() async {
    dynamic order = await InvenTreeSettingsManager().getValue("${prefix}ordering_order", "+");

    return order == "+" ? "+" : "-";
  }

  // Return string for determining 'ordering' of paginated list
  Future<String> get orderingString async {
    dynamic field = await orderingField();
    dynamic order = await orderingOrder();

    // Return an empty string if no field is provided
    if (field.toString().isEmpty) {
      return "";
    }

    return "${order}${field}";
  }

  // Update the (configurable) filters for this paginated list
  Future<void> _saveOrderingOptions(BuildContext context) async {
    // Retrieve stored setting
    dynamic _field = await orderingField();
    dynamic _order = await orderingOrder();

    // Construct the 'ordering' options
    List<Map<String, dynamic>> _opts = [];

    orderingOptions.forEach((k, v) => _opts.add({
      "value": k.toString(),
      "display_name": v.toString()
    }));

    if (_field == null && _opts.isNotEmpty) {
      _field = _opts.first["value"];
    }

    Map<String, dynamic> fields = {
      "ordering_field": {
        "type": "choice",
        "label": "Ordering Field",
        "required": true,
        "choices": _opts,
        "value": _field,
      },
      "ordering_order": {
        "type": "choice",
        "label": "Ordering Direction",
        "required": true,
        "value": _order,
        "choices": [
          {
          "value": "+",
          "display_name": "Ascending",
          },
          {
          "value": "-",
          "display_name": "Descending",
          }
        ]
      }
    };

    // Add in boolean filter options
    for (String key in filterOptions.keys) {
      Map<String, dynamic> opts = filterOptions[key] ?? {};

      // Determine field information
      String label = (opts["label"] ?? key) as String;
      String? help_text = opts["help_text"] as String?;

      bool tristate = (opts["tristate"] ?? true) as bool;

      bool? v = await getBooleanFilterValue(key);

      // Prevent null value if not tristate
      if (!tristate && v == null) {
        v = false;
      }

      // Add in the particular field
      fields[key] = {
        "type": "boolean",
        "display_name": label,
        "label": label,
        "help_text": help_text,
        "value": v,
        "tristate": (opts["tristate"] ?? true) as bool,
      };
    }

    // Launch an interactive form for the user to select options
    launchApiForm(
      context,
      L10().filteringOptions,
      "",
      fields,
      icon: FontAwesomeIcons.circleCheck,
      onSuccess: (Map<String, dynamic> data) async {

        // Extract data from the processed form
        String f = (data["ordering_field"] ?? _field) as String;
        String o = (data["ordering_order"] ?? _order) as String;

        // Save values to settings
        await InvenTreeSettingsManager().setValue("${prefix}ordering_field", f);
        await InvenTreeSettingsManager().setValue("${prefix}ordering_order", o);

        // Save boolean fields
        for (String key in filterOptions.keys) {

          bool? v;

          dynamic value = data[key];

          if (value is bool) {
            v = value;
          }

          await setBooleanFilterValue(key, v);
        }

        // Refresh data from the server
        _pagingController.refresh();
      }
    );
  }

  // Search query term
  String searchTerm = "";

  int resultCount = 0;

  String resultsString() {

    if (resultCount <= 0) {
      return noResultsText;
    } else {
      return "${resultCount} ${L10().results}";
    }
  }

  // Text controller
  final TextEditingController searchController = TextEditingController();

  // Pagination controller
  final PagingController<int, InvenTreeModel> _pagingController = PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });

    super.initState();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  /*
   * Custom function to request a single page of results from the server.
   * Each implementing class must override this function,
   * and return an InvenTreePageResponse object with the correct data format
   */
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    // Default implementation returns null - must be overridden
    return null;
  }

  /*
   * Request a single page of results from the server
   */
  Future<void> _fetchPage(int pageKey) async {
    try {
      Map<String, String> params = widget.filters;

      // Include user search term
      if (searchTerm.isNotEmpty) {
        params["search"] = "${searchTerm}";
      }

      // Use custom query ordering if available
      String o = await orderingString;
      if (o.isNotEmpty) {
        params["ordering"] = o;
      }

      Map<String, String> f = await constructBooleanFilters();

      if (f.isNotEmpty) {
        params.addAll(f);
      }

      final page = await requestPage(
        _pageSize,
        pageKey,
        params
      );

      // We may have disposed of the widget while the request was in progress
      // If this is the case, abort
      if (!mounted) {
        return;
      }

      int pageLength = page?.length ?? 0;
      int pageCount = page?.count ?? 0;

      final isLastPage = pageLength < _pageSize;

      List<InvenTreeModel> items = [];

      if (page != null) {
        for (var result in page.results) {
            items.add(result);
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        final int nextPageKey = pageKey + pageLength;
        _pagingController.appendPage(items, nextPageKey);
      }

      setState(() {
        resultCount = pageCount;
      });
    } catch (error, stackTrace) {
      _pagingController.error = error;

      sentryReportError(
        "paginator.fetchPage",
        error, stackTrace,
      );
    }
  }

  // Callback function when the search term is updated
  void updateSearchTerm() {
    searchTerm = searchController.text;
    _pagingController.refresh();
  }

  // Function to construct a single paginated item
  // Must be overridden in an implementing subclass
  Widget buildItem(BuildContext context, InvenTreeModel item) {

    // This method must be overridden by the child class
    return ListTile(
      title: Text("*** UNIMPLEMENTED ***"),
      subtitle: Text("*** buildItem() is unimplemented for this widget!"),
    );
  }

  // Return a string which is displayed when there are no results
  // Can be overridden by an implementing subclass
  String get noResultsText => L10().noResults;

  @override
  Widget build (BuildContext context) {

    List<Widget> children = [];

    if (widget.showSearch) {
      children.add(buildSearchInput(context));
    }

    children.add(
      Expanded(
        child: CustomScrollView(
            shrinkWrap: true,
            physics: ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            slivers: <Widget>[
              PagedSliverList.separated(
                pagingController: _pagingController,
                builderDelegate: PagedChildBuilderDelegate<InvenTreeModel>(
                    itemBuilder: (ctx, item, index) {
                      return buildItem(ctx, item);
                    },
                    noItemsFoundIndicatorBuilder: (context) {
                      return NoResultsWidget(noResultsText);
                    }
                ),
                separatorBuilder: (context, item) => const Divider(height: 1),
              )
            ]
        )
      )
    );

    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: children,
    );
  }

  /*
   * Construct a search input text field for the user to enter a search term
   */
  Widget buildSearchInput(BuildContext context) {
    return ListTile(
      leading: orderingOptions.isEmpty ? null : GestureDetector(
        child: FaIcon(FontAwesomeIcons.sort, color: COLOR_CLICK),
        onTap: () async {
          _saveOrderingOptions(context);
        },
      ),
      trailing: GestureDetector(
        child: FaIcon(
          searchController.text.isEmpty ? FontAwesomeIcons.magnifyingGlass : FontAwesomeIcons.deleteLeft,
          color: searchController.text.isNotEmpty ? COLOR_DANGER : COLOR_CLICK,
        ),
        onTap: () {
          searchController.clear();
          updateSearchTerm();
        },
      ),
      title: TextFormField(
        controller: searchController,
        onChanged: (value) {
          updateSearchTerm();
        },
        decoration: InputDecoration(
          hintText: L10().search,
          helperText: resultsString(),
        ),
      )
    );
  }
}


class NoResultsWidget extends StatelessWidget {

  const NoResultsWidget(this.description);

  final String description;

  @override
  Widget build(BuildContext context) {

    return ListTile(
      title: Text(
        description,
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
      leading: FaIcon(FontAwesomeIcons.circleExclamation, color: COLOR_WARNING),
    );
  }

}
