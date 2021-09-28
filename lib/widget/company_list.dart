
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:infinite_scroll_pagination/infinite_scroll_pagination.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/company_detail.dart";

import "package:inventree/l10.dart";


class CompanyListWidget extends StatefulWidget {

  const CompanyListWidget(this.title, this.filters, {Key? key}) : super(key: key);

  final String title;

  final Map<String, String> filters;

  @override
  _CompanyListWidgetState createState() => _CompanyListWidgetState(title, filters);
}


class _CompanyListWidgetState extends RefreshableState<CompanyListWidget> {

  _CompanyListWidgetState(this.title, this.filters);

  final String title;

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => title;

  @override
  Widget getBody(BuildContext context) {

    return PaginatedCompanyList(filters);

  }

}


class PaginatedCompanyList extends StatefulWidget {

  const PaginatedCompanyList(this.filters, {this.onTotalChanged});

  final Map<String, String> filters;

  final Function(int)? onTotalChanged;

  @override
  _CompanyListState createState() => _CompanyListState(filters, onTotalChanged);
}

class _CompanyListState extends State<PaginatedCompanyList> {

  _CompanyListState(this.filters, this.onTotalChanged);
  
  static const _pageSize = 25;

  String _searchTerm = "";

  Function(int)? onTotalChanged;
  
  final Map<String, String> filters;
  
  final PagingController<int, InvenTreeCompany> _pagingController = PagingController(firstPageKey: 0);

  final TextEditingController searchController = TextEditingController();
  
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

      final page = await InvenTreeCompany().listPaginated(
          _pageSize, pageKey, filters: params);

      int pageLength = page?.length ?? 0;
      int pageCount = page?.count ?? 0;

      final isLastPage = pageLength < _pageSize;

      List<InvenTreeCompany> companies = [];

      if (page != null) {
        for (var result in page.results) {
          if (result is InvenTreeCompany) {
            companies.add(result);
          } else {
            print(result.jsondata);
          }
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(companies);
      } else {
        final int nextPageKey = pageKey + pageLength;
        _pagingController.appendPage(companies, nextPageKey);
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

  void updateSearchTerm() {
    _searchTerm = searchController.text;
    _pagingController.refresh();
  }

  Widget _buildCompany(BuildContext context, InvenTreeCompany company) {

    return ListTile(
      title: Text(company.name),
      subtitle: Text(company.description),
      leading: InvenTreeAPI().getImage(
        company.image,
        width: 40,
        height: 40
      ),
      onTap: () async {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyDetailWidget(company)));
      },
    );
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
                builderDelegate: PagedChildBuilderDelegate<InvenTreeCompany>(
                  itemBuilder: (context, item, index) {
                    return _buildCompany(context, item);
                  },
                  noItemsFoundIndicatorBuilder: (context) {
                    return NoResultsWidget(L10().companyNoResults);
                  }
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