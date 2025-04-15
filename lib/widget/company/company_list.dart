
import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";


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
  String getAppBarTitle() => widget.title;

  Future<void> _addCompany(BuildContext context) async {

    InvenTreeCompany().createForm(
      context,
      L10().companyAdd,
      data: widget.filters,
      onSuccess: (result) async {
        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var company = InvenTreeCompany.fromJson(data);
          company.goToDetailPage(context);
        }
      }
    );
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreeAPI().checkPermission("company", "add")) {
      actions.add(
          SpeedDialChild(
              child: Icon(TablerIcons.circle_plus, color: Colors.green),
              label: L10().companyAdd,
              onTap: () {
                _addCompany(context);
              }
          )
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return PaginatedCompanyList(widget.title, widget.filters);
  }

}

class PaginatedCompanyList extends PaginatedSearchWidget {

  const PaginatedCompanyList(this.companyTitle, Map<String, String> filters) : super(filters: filters);

  final String companyTitle;

  @override
  String get searchTitle => companyTitle;

  @override
  _CompanyListState createState() => _CompanyListState();
}

class _CompanyListState extends PaginatedSearchState<PaginatedCompanyList> {

  _CompanyListState() : super();

  @override
  Map<String, Map<String, dynamic>> get filterOptions {

    Map<String, Map<String, dynamic>> filters = {};

    if (InvenTreeAPI().supportsCompanyActiveStatus) {
      filters["active"] = {
        "label": L10().filterActive,
        "help_text": L10().filterActiveDetail,
        "tristate": true,
      };
    }

    return filters;
  }

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
      leading: InvenTreeAPI().getThumbnail(company.image),
      onTap: () async {
        company.goToDetailPage(context);
      },
    );
  }
}
