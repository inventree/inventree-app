import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/paginator.dart";

class PaginatedSOAllocationList extends PaginatedSearchWidget {
  const PaginatedSOAllocationList(Map<String, String> filters)
    : super(filters: filters);

  @override
  String get searchTitle => L10().allocatedStock;

  @override
  _PaginatedSOAllocationListState createState() =>
      _PaginatedSOAllocationListState();
}

class _PaginatedSOAllocationListState
    extends PaginatedSearchState<PaginatedSOAllocationList> {
  _PaginatedSOAllocationListState() : super();

  @override
  String get prefix => "so_allocation_";

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
    final page = await InvenTreeSalesOrderAllocation().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeSalesOrderAllocation allocation =
        model as InvenTreeSalesOrderAllocation;

    InvenTreePart? part = allocation.part;
    InvenTreeStockItem? stockItem = allocation.stockItem;
    InvenTreeStockLocation? location = allocation.location;

    return ListTile(
      title: Text(part?.fullname ?? ""),
      subtitle: Text(location?.pathstring ?? L10().locationNotSet),
      onTap: () async {
        stockItem?.goToDetailPage(context);
      },
      leading: InvenTreeAPI().getThumbnail(allocation.part?.thumbnail ?? ""),
      trailing: LargeText(stockItem?.serialOrQuantityDisplay() ?? ""),
    );
  }
}
