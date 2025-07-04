import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/widget/link_icon.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

class SOExtraLineListWidget extends StatefulWidget {
  const SOExtraLineListWidget(this.order, {this.filters = const {}, Key? key})
    : super(key: key);

  final InvenTreeSalesOrder order;

  final Map<String, String> filters;

  @override
  _SalesOrderExtraLineListWidgetState createState() =>
      _SalesOrderExtraLineListWidgetState();
}

class _SalesOrderExtraLineListWidgetState
    extends RefreshableState<SOExtraLineListWidget> {
  _SalesOrderExtraLineListWidgetState();

  @override
  String getAppBarTitle() => L10().extraLineItems;

  Future<void> _addLineItem(BuildContext context) async {
    var fields = InvenTreeSOExtraLineItem().formFields();

    fields["order"]?["value"] = widget.order.pk;

    InvenTreeSOExtraLineItem().createForm(
      context,
      L10().lineItemAdd,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().lineItemUpdated, success: true);
      },
    );
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.order.canEdit) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.circle_plus, color: Colors.green),
          label: L10().lineItemAdd,
          onTap: () {
            _addLineItem(context);
          },
        ),
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return PaginatedSOExtraLineList(widget.filters);
  }
}

class PaginatedSOExtraLineList extends PaginatedSearchWidget {
  const PaginatedSOExtraLineList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().extraLineItems;

  @override
  _PaginatedSOExtraLineListState createState() =>
      _PaginatedSOExtraLineListState();
}

class _PaginatedSOExtraLineListState
    extends PaginatedSearchState<PaginatedSOExtraLineList> {
  _PaginatedSOExtraLineListState() : super();

  @override
  String get prefix => "so_extra_line_";

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeSOExtraLineItem().listPaginated(
      limit,
      offset,
      filters: params,
    );
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeSOExtraLineItem line = model as InvenTreeSOExtraLineItem;

    return ListTile(
      title: Text(line.reference),
      subtitle: Text(line.description),
      trailing: LargeText(line.quantity.toString()),
      onTap: () {
        line.goToDetailPage(context).then((_) {
          refresh();
        });
      },
    );
  }
}
