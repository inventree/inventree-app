import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

class POExtraLineListWidget extends StatefulWidget {
  const POExtraLineListWidget(this.order, {this.filters = const {}, Key? key})
      : super(key: key);

  final InvenTreePurchaseOrder order;

  final Map<String, String> filters;

  @override
  _PurchaseOrderExtraLineListWidgetState createState() =>
      _PurchaseOrderExtraLineListWidgetState();
}

class _PurchaseOrderExtraLineListWidgetState
    extends RefreshableState<POExtraLineListWidget> {
  _PurchaseOrderExtraLineListWidgetState();

  @override
  String getAppBarTitle() => L10().extraLineItems;

  Future<void> _addLineItem(BuildContext context) async {
    var fields = InvenTreePOExtraLineItem().formFields();

    fields["order"]?["value"] = widget.order.pk;

    InvenTreePOExtraLineItem().createForm(context, L10().lineItemAdd,
        fields: fields, onSuccess: (data) async {
      refresh(context);
      showSnackIcon(L10().lineItemUpdated, success: true);
    });
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.order.canEdit) {
      actions.add(SpeedDialChild(
          child: Icon(TablerIcons.circle_plus, color: Colors.green),
          label: L10().lineItemAdd,
          onTap: () {
            _addLineItem(context);
          }));
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPOExtraLineList(widget.filters);
  }
}

class PaginatedPOExtraLineList extends PaginatedSearchWidget {
  const PaginatedPOExtraLineList(Map<String, String> filters)
      : super(filters: filters);

  @override
  String get searchTitle => L10().extraLineItems;

  @override
  _PaginatedPOExtraLineListState createState() =>
      _PaginatedPOExtraLineListState();
}

class _PaginatedPOExtraLineListState
    extends PaginatedSearchState<PaginatedPOExtraLineList> {
  _PaginatedPOExtraLineListState() : super();

  @override
  String get prefix => "po_extra_line_";

  @override
  Future<InvenTreePageResponse?> requestPage(
      int limit, int offset, Map<String, String> params) async {
    final page = await InvenTreePOExtraLineItem()
        .listPaginated(limit, offset, filters: params);
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreePOExtraLineItem line = model as InvenTreePOExtraLineItem;

    return ListTile(
      title: Text(line.reference),
      subtitle: Text(line.description),
      trailing: Text(line.quantity.toString()),
      onTap: () {
        line.goToDetailPage(context).then((_) {
          refresh();
        });
      },
    );
  }
}
