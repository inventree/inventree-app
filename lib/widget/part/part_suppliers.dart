import "dart:core";

import "package:inventree/l10.dart";

import "package:inventree/api.dart";

import "package:flutter/material.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/widget/company/company_detail.dart";
import "package:inventree/widget/refreshable_state.dart";

class PartSupplierWidget extends StatefulWidget {

  const PartSupplierWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartSupplierState createState() => _PartSupplierState(part);

}


class _PartSupplierState extends RefreshableState<PartSupplierWidget> {

  _PartSupplierState(this.part);

  final InvenTreePart part;

  List<InvenTreeSupplierPart> _supplierParts = [];

  @override
  Future<void> request(BuildContext context) async {
    // TODO - Request list of suppliers for the part
    await part.reload();
    _supplierParts = await part.getSupplierParts();
  }

  @override
  String getAppBarTitle() => L10().partSuppliers;

  @override
  List<Widget> appBarActions(BuildContext contexts) {
    // TODO
    return [];
  }

  Widget _supplierPartTile(BuildContext context, int index) {

    InvenTreeSupplierPart _part = _supplierParts[index];

    return ListTile(
      leading: InvenTreeAPI().getThumbnail(_part.supplierImage),
      title: Text("${_part.SKU}"),
      subtitle: Text("${_part.manufacturerName}: ${_part.MPN}"),
      onTap: () async {
        var company = await InvenTreeCompany().get(_part.supplierId);

        if (company != null && company is InvenTreeCompany) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CompanyDetailWidget(company)
              )
          );
        }
      },
    );
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      separatorBuilder: (_, __) => const Divider(height: 3),
      itemCount: _supplierParts.length,
      itemBuilder: _supplierPartTile,
    );
  }

}