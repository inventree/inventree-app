
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/bom.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/part_detail.dart";
import 'package:inventree/widget/progress.dart';
import "package:inventree/widget/refreshable_state.dart";


/*
 * Widget for displaying a Bill of Materials for a specified Part instance
 */
class BillOfMaterialsWidget extends StatefulWidget {

  const BillOfMaterialsWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _BillOfMaterialsState createState() => _BillOfMaterialsState(part);
}

class _BillOfMaterialsState extends RefreshableState<BillOfMaterialsWidget> {
  _BillOfMaterialsState(this.part);

  final InvenTreePart part;

  bool showFilterOptions = false;

  @override
  String getAppBarTitle(BuildContext context) => L10().billOfMaterials;

  @override
  List<Widget> getAppBarActions(BuildContext context) => [
    IconButton(
      icon: FaIcon(FontAwesomeIcons.filter),
      onPressed: () async {
        setState(() {
          showFilterOptions = !showFilterOptions;
        });
      },
    )
  ];

  @override
  Widget getBody(BuildContext context) {
    return PaginatedBomList(
      {
        "part": part.pk.toString(),
      },
      showFilterOptions,
    );
  }
}


/*
 * Create a paginated widget displaying a list of BomItem objects
 */
class PaginatedBomList extends PaginatedSearchWidget {

  const PaginatedBomList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedBomListState createState() => _PaginatedBomListState();
}


class _PaginatedBomListState extends PaginatedSearchState<PaginatedBomList> {

  _PaginatedBomListState() : super();

  @override
  String get prefix => "bom_";

  @override
  Map<String, String> get orderingOptions => {
    "quantity": L10().quantity,
    "sub_part": L10().part,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "sub_part_assembly": {
      "label": L10().filterAssembly,
      "help_text": L10().filterAssemblyDetail,
    }
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final page = await InvenTreeBomItem().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreeBomItem bomItem = model as InvenTreeBomItem;

    InvenTreePart? subPart = bomItem.subPart;

    String title = subPart?.fullname ?? "error - no name";

    return ListTile(
      title: Text(title),
      subtitle: Text(bomItem.reference),
      trailing: Text(
        simpleNumberString(bomItem.quantity),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      leading: InvenTreeAPI().getImage(
        subPart?.thumbnail ?? "",
        width: 40,
        height: 40,
      ),
      onTap: subPart == null ? null : () async {

        showLoadingOverlay(context);
        var part = await InvenTreePart().get(bomItem.subPartId);
        hideLoadingOverlay();

        if (part is InvenTreePart) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
        }
      },
    );
  }
}