

import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/bom.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/refreshable_state.dart";


/*
 * Widget for displaying a list of BomItems for the specified 'parent' Part instance
 */
class BomList extends StatefulWidget {

  const BomList(this.parent);

  final InvenTreePart parent;

  @override
  _BomListState createState() => _BomListState(parent);

}


class _BomListState extends RefreshableState<BomList> {

  _BomListState(this.parent);

  final InvenTreePart parent;

  @override
  String getAppBarTitle(BuildContext context) => L10().billOfMaterials;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedBomList({
      "part": parent.pk.toString(),
    });
  }
}


/*
 * Create a paginated widget displaying a list of BomItem objects
 */
class PaginatedBomList extends StatefulWidget {

  const PaginatedBomList(this.filters, {this.onTotalChanged});

  final Map<String, String> filters;

  final Function(int)? onTotalChanged;

  @override
  _PaginatedBomListState createState() => _PaginatedBomListState(filters, onTotalChanged);

}


class _PaginatedBomListState extends PaginatedSearchState<PaginatedBomList> {

  _PaginatedBomListState(Map<String, String> filters, this.onTotalChanged) : super(filters);

  Function(int)? onTotalChanged;

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
    String description = subPart?.description ?? "error - no description";

    return ListTile(
      title: Text(title),
      subtitle: Text(description),
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
        InvenTreePart().get(bomItem.subPartId).then((var part) {
          if (part is InvenTreePart) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
          }
        });
      },
    );
  }
}