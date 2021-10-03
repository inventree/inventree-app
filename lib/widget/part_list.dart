import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/inventree/sentry.dart';
import 'package:inventree/widget/paginator.dart';
import 'package:inventree/widget/part_detail.dart';
import 'package:inventree/widget/refreshable_state.dart';

import '../api.dart';
import '../app_settings.dart';
import '../l10.dart';


class PartList extends StatefulWidget {

  const PartList(this.filters);

  final Map<String, String> filters;

  @override
  _PartListState createState() => _PartListState(filters);
}


class _PartListState extends RefreshableState<PartList> {

  _PartListState(this.filters);

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => L10().parts;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPartList(filters);
  }

}


class PaginatedPartList extends StatefulWidget {

  const PaginatedPartList(this.filters, {this.onTotalChanged});

  final Map<String, String> filters;

  final Function(int)? onTotalChanged;

  @override
  _PaginatedPartListState createState() => _PaginatedPartListState(filters, onTotalChanged);
}


class _PaginatedPartListState extends State<PaginatedPartList> {

  _PaginatedPartListState(this.filters, this.onTotalChanged);

  static const _pageSize = 25;

  String _searchTerm = "";

  Function(int)? onTotalChanged;

  final Map<String, String> filters;

  final PagingController<int, InvenTreePart> _pagingController = PagingController(firstPageKey: 0);

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

  int resultCount = 0;

  Future<void> _fetchPage(int pageKey) async {
    try {

      Map<String, String> params = filters;

      params["search"] = _searchTerm;

      final bool cascade = await InvenTreeSettingsManager().getBool("partSubcategory", true);

      params["cascade"] = "${cascade}";

      final page = await InvenTreePart().listPaginated(_pageSize, pageKey, filters: params);
      int pageLength = page?.length ?? 0;
      int pageCount = page?.count ?? 0;

      final isLastPage = pageLength < _pageSize;

      // Construct a list of part objects
      List<InvenTreePart> parts = [];

      if (page != null) {
        for (var result in page.results) {
          if (result is InvenTreePart) {
            parts.add(result);
          }
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(parts);
      } else {
        final int nextPageKey = pageKey + pageLength;
        _pagingController.appendPage(parts, nextPageKey);
      }

      if (onTotalChanged != null) {
        onTotalChanged!(pageCount);
      }

      setState(() {
        resultCount = pageCount;
      });

    } catch (error, stackTrace) {
      print("Error! - ${error.toString()}");
      _pagingController.error = error;

      sentryReportError(error, stackTrace);
    }
  }

  void _openPart(BuildContext context, int pk) {
    // Attempt to load the part information
    InvenTreePart().get(pk).then((var part) {
      if (part is InvenTreePart) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
      }
    });
  }

  Widget _buildPart(BuildContext context, InvenTreePart part) {
    return ListTile(
      title: Text(part.fullname),
      subtitle: Text("${part.description}"),
      trailing: Text("${part.inStockString}"),
      leading: InvenTreeAPI().getImage(
        part.thumbnail,
        width: 40,
        height: 40,
      ),
      onTap: () {
        _openPart(context, part.pk);
      },
    );
  }

  final TextEditingController searchController = TextEditingController();

  void updateSearchTerm() {

    _searchTerm = searchController.text;
    _pagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        PaginatedSearchWidget(searchController, updateSearchTerm, resultCount),
        Expanded(
            child: CustomScrollView(
              shrinkWrap: true,
              physics: ClampingScrollPhysics(),
              scrollDirection: Axis.vertical,
              slivers: [
                PagedSliverList.separated(
                  pagingController: _pagingController,
                  builderDelegate: PagedChildBuilderDelegate<InvenTreePart>(
                    itemBuilder: (context, item, index) {
                      return _buildPart(context, item);
                    },
                    noItemsFoundIndicatorBuilder: (context) {
                      return NoResultsWidget(L10().partNoResults);
                    },
                  ),
                  separatorBuilder: (context, index) => const Divider(height: 1),
                )
              ],
            )
        )
      ],
    );
  }
}