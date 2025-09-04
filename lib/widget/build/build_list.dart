import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/build.dart";

/*
 * Widget class for displaying a list of Build Orders
 */
class BuildOrderListWidget extends StatefulWidget {
  const BuildOrderListWidget({this.filters = const {}, Key? key})
    : super(key: key);

  final Map<String, String> filters;

  @override
  _BuildOrderListWidgetState createState() => _BuildOrderListWidgetState();
}

class _BuildOrderListWidgetState
    extends RefreshableState<BuildOrderListWidget> {
  _BuildOrderListWidgetState();

  @override
  String getAppBarTitle() => L10().buildOrders;

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    // Add create button if user has permission
    // Using canCreate instead of specific permission check
    if (InvenTreeBuildOrder().canCreate) {
      actions.add(
        SpeedDialChild(
          child: const Icon(TablerIcons.circle_plus),
          label: L10().buildOrderCreate,
          onTap: () {
            _createBuildOrder(context);
          },
        ),
      );
    }

    return actions;
  }

  // Launch form to create a new BuildOrder
  Future<void> _createBuildOrder(BuildContext context) async {
    var fields = InvenTreeBuildOrder().formFields();

    InvenTreeBuildOrder().createForm(
      context,
      L10().buildOrderCreate,
      fields: fields,
      onSuccess: (result) async {
        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var order = InvenTreeBuildOrder.fromJson(data);
          order.goToDetailPage(context);
        }
      },
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    // Build orders don't have barcode functionality yet
    return [];
  }

  @override
  Widget getBody(BuildContext context) {
    return PaginatedBuildOrderList(widget.filters);
  }
}

class PaginatedBuildOrderList extends PaginatedSearchWidget {
  const PaginatedBuildOrderList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().buildOrders;

  @override
  _PaginatedBuildOrderListState createState() =>
      _PaginatedBuildOrderListState();
}

class _PaginatedBuildOrderListState
    extends PaginatedSearchState<PaginatedBuildOrderList> {
  _PaginatedBuildOrderListState() : super();

  @override
  String get prefix => "build_";

  @override
  Map<String, String> get orderingOptions => {
    "reference": L10().reference,
    "part__name": L10().part,
    "status": L10().status,
    "creation_date": L10().creationDate,
    "target_date": L10().targetDate,
    "completion_date": L10().completionDate,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "outstanding": {
      "label": L10().outstanding,
      "help_text": L10().outstandingOrderDetail,
      "tristate": true,
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
    // Make sure the status codes are loaded
    await InvenTreeAPI().fetchStatusCodeData();

    final page = await InvenTreeBuildOrder().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeBuildOrder order = model as InvenTreeBuildOrder;
    InvenTreePart? part = order.partDetail;

    return ListTile(
      title: Text(order.reference),
      subtitle: Text(order.description),
      leading: part != null
          ? InvenTreeAPI().getThumbnail(part.thumbnail)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                BuildOrderStatus.getStatusText(order.status),
                style: TextStyle(
                  color: BuildOrderStatus.getStatusColor(order.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${order.completed.toInt()} / ${order.quantity.toInt()}",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      onTap: () async {
        order.goToDetailPage(context);
      },
    );
  }
}
