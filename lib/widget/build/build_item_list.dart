import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";
import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/build/build_item_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";

class PaginatedBuildItemWidget extends StatefulWidget {
  const PaginatedBuildItemWidget(this.build, {Key? key}) : super(key: key);

  final InvenTreeBuildOrder build;

  @override
  _PaginatedBuildItemWidgetState createState() =>
      _PaginatedBuildItemWidgetState();
}

class _PaginatedBuildItemWidgetState
    extends RefreshableState<PaginatedBuildItemWidget> {
  _PaginatedBuildItemWidgetState();

  @override
  String getAppBarTitle() {
    return L10().allocatedStock;
  }

  @override
  Widget getBody(BuildContext context) {
    Map<String, String> filters = {"build": widget.build.pk.toString()};

    return Column(
      children: [
        ListTile(
          leading: InvenTreeAPI().getThumbnail(
            widget.build.partDetail!.thumbnail,
          ),
          title: Text(widget.build.reference),
          subtitle: Text(L10().allocatedStock),
        ),
        Divider(thickness: 1.25),
        Expanded(child: PaginatedBuildItemList(filters)),
      ],
    );
  }
}

/*
 * Paginated widget class for displaying a list of build order item allocations
 */
class PaginatedBuildItemList extends PaginatedSearchWidget {
  const PaginatedBuildItemList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().allocatedStock;

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
    "stock_item": L10().stockItem,
    "quantity": L10().quantity,
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
      info = "${L10().serialNumber}: ${item.serialNumber}";
    }
    // Show batch code if available
    else if (item.batchCode.isNotEmpty) {
      info = "${L10().batchCode}: ${item.batchCode}";
    }
    // Otherwise show location
    else if (item.locationName.isNotEmpty) {
      info = item.locationPath;
    }

    return ListTile(
      title: Text(item.partName),
      subtitle: Text(info),
      trailing: Text(
        item.quantity.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      leading: InvenTreeAPI().getThumbnail(item.partThumbnail),
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
