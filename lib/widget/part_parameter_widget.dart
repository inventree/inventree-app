import "package:flutter/material.dart";
import "package:inventree/inventree/model.dart";

import "package:inventree/l10.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";

/*
 * Widget for displaying a list of parameters associated with a given Part instance
 */
class PartParameterWidget extends StatefulWidget {

  const PartParameterWidget(this.part);

  final InvenTreePart part;

  @override
  _ParameterWidgetState createState() => _ParameterWidgetState();
}


class _ParameterWidgetState extends RefreshableState<PartParameterWidget> {
  _ParameterWidgetState();

  @override
  String getAppBarTitle(BuildContext context) {
    return L10().parameters;
  }

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    return [];
  }

  @override
  Widget getBody(BuildContext context) {

    Map<String, String> filters = {
      "part": widget.part.pk.toString()
    };

    return Column(
      children: [
        Expanded(
          child: PaginatedParameterList(
            filters,
            false,
          )
        )
      ],
    );
  }
}


/*
 * Widget for displaying a paginated list of Part parameters
 */
class PaginatedParameterList extends PaginatedSearchWidget {

  const PaginatedParameterList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedParameterState createState() => _PaginatedParameterState();
}


class _PaginatedParameterState extends PaginatedSearchState<PaginatedParameterList> {

  _PaginatedParameterState() : super();

  @override
  String get prefix => "parameters_";

  @override
  Map<String, String> get orderingOptions => {
    // TODO
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    // TODO
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final page = await InvenTreePartParameter().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreePartParameter parameter = model as InvenTreePartParameter;

    return ListTile(
      title: Text(parameter.name),
      subtitle: Text(parameter.description),
      trailing: Text(parameter.valueString),
    );
  }
}