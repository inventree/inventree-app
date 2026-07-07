import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/transfer_order.dart";

import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";

/*
 * Widget class for displaying a list of Transfer Orders
 */
class TransferOrderListWidget extends StatefulWidget {
  const TransferOrderListWidget({this.filters = const {}, Key? key})
    : super(key: key);

  final Map<String, String> filters;

  @override
  _TransferOrderListWidgetState createState() =>
      _TransferOrderListWidgetState();
}

class _TransferOrderListWidgetState
    extends RefreshableState<TransferOrderListWidget> {
  _TransferOrderListWidgetState();

  @override
  String getAppBarTitle() => L10().transferOrders;

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreeTransferOrder().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.circle_plus),
          label: L10().transferOrderCreate,
          onTap: () {
            _createTransferOrder(context);
          },
        ),
      );
    }

    return actions;
  }

  // Launch form to create a new TransferOrder
  Future<void> _createTransferOrder(BuildContext context) async {
    var fields = InvenTreeTransferOrder().formFields();

    InvenTreeTransferOrder().createForm(
      context,
      L10().transferOrderCreate,
      fields: fields,
      onSuccess: (result) async {
        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var order = InvenTreeTransferOrder.fromJson(data);
          order.goToDetailPage(context);
        }
      },
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    // Transfer orders don't have barcode functionality yet
    return [];
  }

  @override
  Widget getBody(BuildContext context) {
    return PaginatedTransferOrderList(widget.filters);
  }
}

class PaginatedTransferOrderList extends PaginatedSearchWidget {
  const PaginatedTransferOrderList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().transferOrders;

  @override
  _PaginatedTransferOrderListState createState() =>
      _PaginatedTransferOrderListState();
}

class _PaginatedTransferOrderListState
    extends PaginatedSearchState<PaginatedTransferOrderList> {
  _PaginatedTransferOrderListState() : super();

  @override
  String get prefix => "to_";

  @override
  Map<String, String> get orderingOptions => {
    "reference": L10().reference,
    "status": L10().status,
    "target_date": L10().targetDate,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "outstanding": {
      "label": L10().outstanding,
      "help_text": L10().outstandingOrderDetail,
      "tristate": true,
      "default": true,
    },
    "overdue": {
      "label": L10().overdue,
      "help_text": L10().overdueDetail,
      "tristate": true,
    },
    "assigned_to_me": {
      "label": L10().assignedToMe,
      "help_text": L10().assignedToMeDetail,
      "tristate": true,
    },
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeTransferOrder().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeTransferOrder order = model as InvenTreeTransferOrder;

    return ListTile(
      title: Text(order.reference),
      subtitle: Text(order.description),
      trailing: LargeText(
        TransferOrderStatus.getStatusText(order.status),
        color: TransferOrderStatus.getStatusColor(order.status),
      ),
      onTap: () async {
        order.goToDetailPage(context);
      },
    );
  }
}
