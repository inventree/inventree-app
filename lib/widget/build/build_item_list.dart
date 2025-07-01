import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";

// Will use L10 later for internationalization
// import "package:inventree/l10.dart";

import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/model.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/build/build_item_detail.dart";
import "package:inventree/widget/progress.dart";

/*
 * Paginated widget class for displaying a list of build order item allocations
 */
class PaginatedBuildItemList extends PaginatedSearchWidget {
  const PaginatedBuildItemList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => "Stock Allocations"; // Will use L10().stockAllocations later

  @override
  _PaginatedBuildItemListState createState() => _PaginatedBuildItemListState();
}

/*
 * State class for PaginatedBuildItemList
*/
class _PaginatedBuildItemListState
    extends PaginatedSearchState<PaginatedBuildItemList> {
  _PaginatedBuildItemListState() : super();

  @override
  String get prefix => "build_item_";

  @override
  Map<String, String> get orderingOptions => {
    "stock_item": "Stock Item", // Will use L10().stockItem later
    "quantity": "Quantity", // Will use L10().quantity later
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeBuildItem().listPaginated(
      limit,
      offset,
      filters: params,
    );
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeBuildItem item = model as InvenTreeBuildItem;

    // Format the serialized data
    String info = "";

    // Show serial number if available
    if (item.serialNumber.isNotEmpty) {
      info = "SN: ${item.serialNumber}";
    }
    // Show batch code if available
    else if (item.batchCode.isNotEmpty) {
      info = "Batch: ${item.batchCode}";
    }
    // Otherwise show location
    else if (item.locationName.isNotEmpty) {
      info = item.locationPath;
    }

    return ListTile(
      title: Text(item.stockItem?.partName ?? "Stock Item"),
      subtitle: Text(info),
      trailing: Text(
        item.quantity.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      leading: item.stockItem != null && item.stockItem!.partImage.isNotEmpty
          ? SizedBox(
              width: 32,
              height: 32,
              child: InvenTreeAPI().getThumbnail(item.stockItem!.partImage),
            )
          : const Icon(TablerIcons.box),
      onTap: () async {
        showLoadingOverlay();
        await item.reload();
        hideLoadingOverlay();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BuildItemDetailWidget(item)),
        );
      },
    );
  }
}
