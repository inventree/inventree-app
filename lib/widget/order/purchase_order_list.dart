import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/order/purchase_order_detail.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/purchase_order.dart";
import "package:inventree/inventree/purchase_order.dart";

/*
 * Widget class for displaying a list of Purchase Orders
 */
class PurchaseOrderListWidget extends StatefulWidget {

  const PurchaseOrderListWidget({this.filters = const {}, Key? key}) : super(key: key);

  final Map<String, String> filters;

  @override
  _PurchaseOrderListWidgetState createState() => _PurchaseOrderListWidgetState();
}


class _PurchaseOrderListWidgetState extends RefreshableState<PurchaseOrderListWidget> {

  _PurchaseOrderListWidgetState();

  @override
  String getAppBarTitle() => L10().purchaseOrders;

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreePurchaseOrder().canCreate) {
      actions.add(
        SpeedDialChild(
          child: FaIcon(FontAwesomeIcons.circlePlus),
          label: L10().purchaseOrderCreate,
          onTap: () {
            _createPurchaseOrder(context);
          }
        )
      );
    }

    return actions;
  }

  // Launch form to create a new PurchaseOrder
  Future<void> _createPurchaseOrder(BuildContext context) async {
    var fields = InvenTreePurchaseOrder().formFields();

    // Cannot set contact until company is locked in
    fields.remove("contact");

    InvenTreePurchaseOrder().createForm(
      context,
      L10().purchaseOrderCreate,
      fields: fields,
      onSuccess: (result) async {
        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var order = InvenTreePurchaseOrder.fromJson(data);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseOrderDetailWidget(order)
            )
          );
        }
      }
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (api.supportsBarcodePOReceiveEndpoint) {
      actions.add(
        SpeedDialChild(
          child: Icon(Icons.barcode_reader),
          label: L10().scanReceivedParts,
          onTap:() async {
            scanBarcode(
              context,
              handler: POReceiveBarcodeHandler(),
            );
          },
        )
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPurchaseOrderList(widget.filters);
  }
}


class PaginatedPurchaseOrderList extends PaginatedSearchWidget {

  const PaginatedPurchaseOrderList(Map<String, String> filters) : super(filters: filters);

  @override
  String get searchTitle => L10().purchaseOrders;

  @override
  _PaginatedPurchaseOrderListState createState() => _PaginatedPurchaseOrderListState();

}


class _PaginatedPurchaseOrderListState extends PaginatedSearchState<PaginatedPurchaseOrderList> {

  _PaginatedPurchaseOrderListState() : super();

  @override
  String get prefix => "po_";

  @override
  Map<String, String> get orderingOptions => {
    "reference": L10().reference,
    "supplier__name": L10().supplier,
    "status": L10().status,
    "target_date": L10().targetDate,
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
    }
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    await InvenTreeAPI().PurchaseOrderStatus.load();
    final page = await InvenTreePurchaseOrder().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreePurchaseOrder order = model as InvenTreePurchaseOrder;

    InvenTreeCompany? supplier = order.supplier;
    
    return ListTile(
      title: Text(order.reference),
      subtitle: Text(order.description),
      leading: supplier == null ? null : InvenTreeAPI().getThumbnail(supplier.thumbnail),
      trailing: Text(
        InvenTreeAPI().PurchaseOrderStatus.label(order.status),
        style: TextStyle(
          color: InvenTreeAPI().PurchaseOrderStatus.color(order.status),
        ),
      ),
      onTap: () async {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseOrderDetailWidget(order)
          )
        );
      },
    );
  }
}