import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/purchase_order.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/order/po_line_detail.dart";
import "package:inventree/widget/progress.dart";

/*
 * Paginated widget class for displaying a list of purchase order line items
 */
class PaginatedPOLineList extends PaginatedSearchWidget {

  const PaginatedPOLineList(Map<String, String> filters) : super(filters: filters);

  @override
  String get searchTitle => L10().lineItems;

  @override
  _PaginatedPOLineListState createState() => _PaginatedPOLineListState();

}

/*
 * State class for PaginatedPOLineList
*/
class _PaginatedPOLineListState extends PaginatedSearchState<PaginatedPOLineList> {

  _PaginatedPOLineListState() : super();

  @override
  String get prefix => "po_line_";

  @override
  Map<String, String> get orderingOptions => {
    "part": L10().part,
    "SKU": L10().sku,
    "quantity": L10().quantity,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "pending": {
      "label": L10().outstanding,
      "help_text": L10().outstandingOrderDetail,
      "tristate": true,
    },
    "received": {
      "label": L10().received,
      "help_text": L10().receivedFilterDetail,
      "tristate": true,
    }
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {
    
    final page = await InvenTreePOLineItem().listPaginated(limit, offset, filters: params);
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreePOLineItem item = model as InvenTreePOLineItem;
    InvenTreeSupplierPart? supplierPart = item.supplierPart;

    if (supplierPart != null) {
      return ListTile(
        title: Text(supplierPart.SKU),
        subtitle: Text(supplierPart.partName),
        trailing: Text(item.progressString, style: TextStyle(color: item.isComplete ? COLOR_SUCCESS : COLOR_WARNING)),
        leading: InvenTreeAPI().getThumbnail(supplierPart.partImage),
        onTap: () async {
          showLoadingOverlay(context);
          await item.reload();
          hideLoadingOverlay();
          Navigator.push(context, MaterialPageRoute(builder: (context) => POLineDetailWidget(item)));
        },
      );
    } else {
      // Return an error tile
      return ListTile(
        title: Text(L10().error),
        subtitle: Text("supplier part not defined", style: TextStyle(color: COLOR_DANGER)),
      );
    }
  }
}
