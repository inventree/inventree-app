import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:infinite_scroll_pagination/infinite_scroll_pagination.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/l10.dart";


class PaginatedSearchState<T extends StatefulWidget> extends State<T> {

  PaginatedSearchState(this.filters);

  final Map<String, String> filters;

  static const _pageSize = 25;

  // Search query term
  String searchTerm = "";

  int resultCount = 0;

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

  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    // Default implementation returns null - must be overridden
    return null;
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      Map<String, String> params = filters;

      params["search"] = "${searchTerm}";

      final page = await requestPage(
        _pageSize,
        pageKey,
        params
      );

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

  void updateSearchTerm() {
    searchTerm = searchController.text;
    _pagingController.refresh();
  }

  Widget buildItem(BuildContext context, InvenTreeModel item) {

    // This method must be overridden by the child class
    return ListTile(
      title: Text("*** UNIMPLEMENTED ***"),
      subtitle: Text("*** buildItem() is unimplemented for this widget!"),
    );
  }

  String get noResultsText => L10().noResults;

  @override
  Widget build (BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          PaginatedSearchWidget(searchController, updateSearchTerm, resultCount),
          Expanded(
              child: CustomScrollView(
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  slivers: <Widget>[
                    // TODO - Search input
                    PagedSliverList.separated(
                      pagingController: _pagingController,
                      builderDelegate: PagedChildBuilderDelegate<InvenTreeModel>(
                          itemBuilder: (context, item, index) {
                            return buildItem(context, item);
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
        ]
    );
  }

}


class PaginatedSearchWidget extends StatelessWidget {

  const PaginatedSearchWidget(this.controller, this.onChanged, this.results);

  final Function onChanged;

  final int results;

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        child: FaIcon(controller.text.isEmpty ? FontAwesomeIcons.search : FontAwesomeIcons.backspace),
        onTap: () {
          controller.clear();
          onChanged();
        },
      ),
      title: TextFormField(
        controller: controller,
        onChanged: (value) {
          onChanged();
        },
        decoration: InputDecoration(
          hintText: L10().search,
        ),
      ),
      trailing: Text(
        "${results}",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class NoResultsWidget extends StatelessWidget {

  const NoResultsWidget(this.description);

  final String description;

  @override
  Widget build(BuildContext context) {

    return ListTile(
      title: Text(L10().noResults),
      subtitle: Text(description),
      leading: FaIcon(FontAwesomeIcons.exclamationCircle),
    );
  }

}
