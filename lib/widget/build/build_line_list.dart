import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/build.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/build/build_line_detail.dart";
import "package:inventree/widget/progress.dart";

/*
 * Paginated widget class for displaying a list of build order line items
 */
class PaginatedBuildLineList extends PaginatedSearchWidget {
  const PaginatedBuildLineList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().requiredParts;

  @override
  _PaginatedBuildLineListState createState() => _PaginatedBuildLineListState();
}

/*
 * State class for PaginatedBuildLineList
*/
class _PaginatedBuildLineListState
    extends PaginatedSearchState<PaginatedBuildLineList> {
  _PaginatedBuildLineListState() : super();

  @override
  String get prefix => "build_line_";

  @override
  Map<String, String> get orderingOptions => {
    "part": L10().part,
    "reference": L10().reference,
    "quantity": L10().quantity,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "allocated": {
      "label": L10().allocated,
      "help_text": L10().allocatedFilterDetail,
      "tristate": true,
    },
    "completed": {
      "label": L10().complete,
      "help_text": L10().completedFilterDetail,
      "tristate": true,
    },
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeBuildLine().listPaginated(
      limit,
      offset,
      filters: params,
    );
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeBuildLine item = model as InvenTreeBuildLine;

    // Calculate allocation progress
    double progress = 0;
    if (item.requiredQuantity > 0) {
      progress = item.allocatedQuantity / item.requiredQuantity;
    }

    // Clamp to valid range
    progress = progress.clamp(0, 1);

    return ListTile(
      title: Text(item.partName),
      subtitle: Text(
        item.reference.isNotEmpty ? item.reference : L10().referenceNone,
      ),
      trailing: Text(
        "${item.allocatedQuantity.toInt()} / ${item.requiredQuantity.toInt()}",
        style: TextStyle(
          color: progress >= 1 ? COLOR_SUCCESS : COLOR_WARNING,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: item.part != null && item.part!.thumbnail.isNotEmpty
          ? SizedBox(
              width: 32,
              height: 32,
              child: InvenTreeAPI().getThumbnail(item.part!.thumbnail),
            )
          : const Icon(TablerIcons.box),
      onTap: () async {
        showLoadingOverlay();
        await item.reload();
        hideLoadingOverlay();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BuildLineDetailWidget(item)),
        );
      },
    );
  }
}
