import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/transfer_order.dart";

import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/order/transfer_order_line_detail.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/progress.dart";

/*
 * Paginated widget class for displaying a list of parts assigned to a Transfer Order
 */
class PaginatedTransferOrderLineList extends PaginatedSearchWidget {
  const PaginatedTransferOrderLineList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().lineItems;

  @override
  _PaginatedTransferOrderLineListState createState() =>
      _PaginatedTransferOrderLineListState();
}

class _PaginatedTransferOrderLineListState
    extends PaginatedSearchState<PaginatedTransferOrderLineList> {
  _PaginatedTransferOrderLineListState() : super();

  @override
  String get prefix => "to_line_";

  @override
  Map<String, String> get orderingOptions => {
    "part": L10().part,
    "quantity": L10().quantity,
    "target_date": L10().targetDate,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "completed": {
      "label": L10().received,
      "help_text": L10().receivedFilterDetail,
      "tristate": true,
    },
    "allocated": {
      "label": L10().allocated,
      "help_text": L10().allocatedFilterDetail,
      "tristate": true,
    },
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeTransferOrderLineItem().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeTransferOrderLineItem item =
        model as InvenTreeTransferOrderLineItem;

    return ListTile(
      title: Text(item.partName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.partDescription.isNotEmpty) Text(item.partDescription),
          ProgressBar(item.transferred, maximum: item.quantity),
        ],
      ),
      leading: InvenTreeAPI().getThumbnail(item.partImage),
      trailing: LargeText(
        item.progressString,
        color: item.isComplete ? COLOR_SUCCESS : COLOR_WARNING,
      ),
      onTap: () async {
        showLoadingOverlay();
        await item.reload();
        hideLoadingOverlay();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransferOrderLineDetailWidget(item),
          ),
        );
      },
    );
  }
}
