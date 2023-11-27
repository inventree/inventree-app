import "package:flutter/material.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/order/so_line_detail.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/widget/progress.dart";


/*
 * Paginated widget class for displaying a list of sales order line items
 */

class PaginatedSOLineList extends PaginatedSearchWidget {
  const PaginatedSOLineList(Map<String, String> filters) : super(filters: filters);

  @override
  String get searchTitle => L10().lineItems;

  @override
  _PaginatedSOLineListState createState() => _PaginatedSOLineListState();

}


/*
 * State class for PaginatedSOLineList
 */
class _PaginatedSOLineListState extends PaginatedSearchState<PaginatedSOLineList> {

  _PaginatedSOLineListState() : super();

  @override
  String get prefix => "so_line_";

  @override
  Map<String, String> get orderingOptions => {
    "part": L10().part,
    "quantity": L10().quantity,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {

  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {
    final page = await InvenTreeSOLineItem().listPaginated(limit, offset, filters: params);
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeSOLineItem item = model as InvenTreeSOLineItem;
    InvenTreePart? part = item.part;

    if (part != null) {
      return ListTile(
        title: Text(part.name),
        subtitle: Text(part.description),
        leading: InvenTreeAPI().getThumbnail(part.thumbnail),
        trailing: Text(item.progressString, style: TextStyle(color: item.isComplete ? COLOR_SUCCESS : COLOR_WARNING)),
        onTap: () async {
          showLoadingOverlay(context);
          await item.reload();
          hideLoadingOverlay();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SoLineDetailWidget(item))
          );
        }
      );
    } else {
      return ListTile(
        title: Text(L10().error),
        subtitle: Text("Missing part detail", style: TextStyle(color: COLOR_DANGER)),
      );
    }
  }

}
