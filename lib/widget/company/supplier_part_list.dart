import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/company/supplier_part_detail.dart";


/*
 * Widget for displaying a list of Supplier Part instances
 */
class SupplierPartList extends StatefulWidget {

  const SupplierPartList(this.filters);

  final Map<String, String> filters;

  @override
  _SupplierPartListState createState() => _SupplierPartListState();
}


class _SupplierPartListState extends RefreshableState<SupplierPartList> {

  @override
  String getAppBarTitle() => L10().supplierParts;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedSupplierPartList(widget.filters);
  }

}


class PaginatedSupplierPartList extends PaginatedSearchWidget {

  const PaginatedSupplierPartList(Map<String, String> filters) : super(filters: filters);

  @override
  String get searchTitle => L10().supplierParts;

  @override
  _PaginatedSupplierPartListState createState() => _PaginatedSupplierPartListState();

}


class _PaginatedSupplierPartListState extends PaginatedSearchState<PaginatedSupplierPartList> {

  _PaginatedSupplierPartListState() : super();

  @override
  String get prefix => "supplierpart_";

  @override
  Map<String, String> get orderingOptions => {};

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {};

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {
    final page = await InvenTreeSupplierPart().listPaginated(limit, offset, filters: params);
    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeSupplierPart supplierPart = model as InvenTreeSupplierPart;

    return ListTile(
      title: Text(supplierPart.SKU),
      subtitle: Text(supplierPart.partName),
      leading: InvenTreeAPI().getThumbnail(supplierPart.supplierImage),
      trailing: InvenTreeAPI().getThumbnail(supplierPart.partImage),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupplierPartDetailWidget(supplierPart)
          )
        );
      },
    );
  }
}