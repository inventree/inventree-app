import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/transfer_order.dart";
import "package:inventree/l10.dart";

import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";

/*
 * Full-page widget for displaying the stock items allocated against a
 * single Transfer Order line item
 */
class TransferOrderAllocationWidget extends StatefulWidget {
  const TransferOrderAllocationWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeTransferOrderLineItem item;

  @override
  _TransferOrderAllocationWidgetState createState() =>
      _TransferOrderAllocationWidgetState();
}

class _TransferOrderAllocationWidgetState
    extends RefreshableState<TransferOrderAllocationWidget> {
  _TransferOrderAllocationWidgetState();

  @override
  String getAppBarTitle() => L10().allocatedStock;

  @override
  Widget getBody(BuildContext context) {
    Map<String, String> filters = {"line": widget.item.pk.toString()};

    return Column(
      children: [
        ListTile(
          leading: InvenTreeAPI().getThumbnail(widget.item.partImage),
          title: Text(widget.item.partName),
          subtitle: Text(L10().allocatedStock),
        ),
        Divider(thickness: 1.25),
        Expanded(child: PaginatedTransferOrderAllocationList(filters)),
      ],
    );
  }
}

/*
 * Paginated widget class for displaying a list of transfer order line item allocations
 */
class PaginatedTransferOrderAllocationList extends PaginatedSearchWidget {
  const PaginatedTransferOrderAllocationList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().allocatedStock;

  @override
  _PaginatedTransferOrderAllocationListState createState() =>
      _PaginatedTransferOrderAllocationListState();
}

class _PaginatedTransferOrderAllocationListState
    extends PaginatedSearchState<PaginatedTransferOrderAllocationList> {
  _PaginatedTransferOrderAllocationListState() : super();

  @override
  String get prefix => "to_allocation_";

  @override
  Map<String, String> get orderingOptions => {};

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {};

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeTransferOrderAllocation().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeTransferOrderAllocation allocation =
        model as InvenTreeTransferOrderAllocation;

    var stockItem = allocation.stockItem;
    var location = allocation.location;

    return ListTile(
      title: Text(stockItem?.serialOrQuantityDisplay() ?? ""),
      subtitle: Text(location?.pathstring ?? L10().locationNotSet),
      leading: InvenTreeAPI().getThumbnail(allocation.part?.thumbnail ?? ""),
      trailing: LargeText(simpleNumberString(allocation.quantity)),
      onTap: () async {
        stockItem?.goToDetailPage(context);
      },
    );
  }
}
