
import "package:flutter/material.dart";

import "package:inventree/api.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/company_detail.dart";


/*
 * Widget for displaying a filterable list of Company instances
 */
class CompanyListWidget extends StatefulWidget {

  const CompanyListWidget(this.title, this.filters, {Key? key}) : super(key: key);

  final String title;

  final Map<String, String> filters;

  @override
  _CompanyListWidgetState createState() => _CompanyListWidgetState();
}


class _CompanyListWidgetState extends RefreshableState<CompanyListWidget> {

  _CompanyListWidgetState();

  @override
  String getAppBarTitle(BuildContext context) => widget.title;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedCompanyList(widget.filters, true);
  }

}

class PaginatedCompanyList extends PaginatedSearchWidget {

  const PaginatedCompanyList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _CompanyListState createState() => _CompanyListState();
}

class _CompanyListState extends PaginatedSearchState<PaginatedCompanyList> {

  _CompanyListState() : super();

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final page = await InvenTreeCompany().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreeCompany company = model as InvenTreeCompany;

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
}