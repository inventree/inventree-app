import "package:flutter/material.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/parameter.dart";

import "package:inventree/l10.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";

/*
 * Widget for displaying a list of parameters associated with a given Part instance
 */
class ParameterWidget extends StatefulWidget {
  const ParameterWidget(this.modelType, this.modelId, this.editable) : super();

  final String modelType;
  final int modelId;
  final bool editable;

  @override
  _ParameterWidgetState createState() => _ParameterWidgetState();
}

class _ParameterWidgetState extends RefreshableState<ParameterWidget> {
  _ParameterWidgetState();

  @override
  String getAppBarTitle() {
    return L10().parameters;
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    return [];
  }

  @override
  Widget getBody(BuildContext context) {
    Map<String, String> filters = {
      "model_type": widget.modelType,
      "model_id": widget.modelId.toString(),
    };

    return Column(children: [Expanded(child: PaginatedParameterList(filters, widget.editable))]);
  }
}

/*
 * Widget for displaying a paginated list of Part parameters
 */
class PaginatedParameterList extends PaginatedSearchWidget {
  const PaginatedParameterList(Map<String, String> filters, this.editable)
    : super(filters: filters);

  final bool editable;

  @override
  String get searchTitle => L10().parameters;

  @override
  _PaginatedParameterState createState() => _PaginatedParameterState();
}

class _PaginatedParameterState
    extends PaginatedSearchState<PaginatedParameterList> {
  _PaginatedParameterState() : super();

  @override
  String get prefix => "parameters_";

  @override
  Map<String, String> get orderingOptions => {};

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    // TODO
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeParameter().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  Future<void> editParameter(InvenTreeParameter parameter) async {
    // Checkbox values are handled separately
    if (parameter.is_checkbox) {
      return;
    } else {
      parameter.editForm(
        context,
        L10().editParameter,
        onSuccess: (data) async {
          updateSearchTerm();
        },
      );
    }
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeParameter parameter = model as InvenTreeParameter;

    String title = parameter.name;

    if (parameter.units.isNotEmpty) {
      title += " [${parameter.units}]";
    }

    return ListTile(
      title: Text(title),
      subtitle: Text(parameter.description),
      trailing: parameter.is_checkbox
          ? Switch(
              value: parameter.as_bool,
              onChanged: (bool value) {
                if (widget.editable) {
                  showLoadingOverlay();
                  parameter.update(values: {"data": value.toString()}).then((
                    value,
                  ) async {
                    hideLoadingOverlay();
                    updateSearchTerm();
                  });
                }
              },
            )
          : Text(parameter.value),
      onTap: parameter.is_checkbox
          ? null
          : () async {
              if (widget.editable) {
                editParameter(parameter);
              }
            },
    );
  }
}
