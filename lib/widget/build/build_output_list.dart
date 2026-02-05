import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/stock/stock_detail.dart";

/*
 * Paginated widget class for displaying a list of build order outputs (manufactured items)
 */
class PaginatedBuildOutputList extends PaginatedSearchWidget {
  const PaginatedBuildOutputList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().buildOutputs;

  @override
  _PaginatedBuildOutputListState createState() =>
      _PaginatedBuildOutputListState();
}

/*
 * State class for PaginatedBuildOutputList
*/
class _PaginatedBuildOutputListState
    extends PaginatedSearchState<PaginatedBuildOutputList> {
  _PaginatedBuildOutputListState() : super();

  @override
  String get prefix => "build_output_";

  @override
  Map<String, String> get orderingOptions => {
    "part": L10().part,
    "serial": L10().serialNumber,
    "quantity": L10().quantity,
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    // Use the stock API endpoint with a filter for stock items that are build outputs
    // The 'build' filter specifies which build order the stock items are outputs of
    params["is_building"] = "false"; // Only show completed items
    params["status"] = "10"; // Status 10 = 'OK' for stock items
    params["tracked_by"] = "2,3"; // Serialized or batch tracked

    final page = await InvenTreeStockItem().listPaginated(
      limit,
      offset,
      filters: params,
    );
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeStockItem stockItem = model as InvenTreeStockItem;

    // Format the information to display
    String info = "";

    // Show serial number if available
    if (stockItem.serialNumber.isNotEmpty) {
      info = "${L10().serialNumber}: ${stockItem.serialNumber}";
    }
    // Show batch code if available
    else if (stockItem.batch.isNotEmpty) {
      info = "${L10().batchCode}: ${stockItem.batch}";
    }
    // Otherwise show location
    else if (stockItem.locationId > 0) {
      // Use locationName if available
      info = stockItem.getString("name", subKey: "location_detail");

      // Try to get the path if available
      String path = stockItem.getString(
        "pathstring",
        subKey: "location_detail",
      );
      if (path.isNotEmpty) {
        info = path;
      }
    }

    return ListTile(
      title: Text(stockItem.partName),
      subtitle: Text(info),
      trailing: Text(
        stockItem.quantity.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      leading: stockItem.partThumbnail.isNotEmpty
          ? SizedBox(
              width: 32,
              height: 32,
              child: InvenTreeAPI().getThumbnail(stockItem.partThumbnail),
            )
          : const Icon(TablerIcons.box),
      onTap: () async {
        showLoadingOverlay();
        await stockItem.reload();
        hideLoadingOverlay();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StockDetailWidget(stockItem)),
        );
      },
    );
  }
}
