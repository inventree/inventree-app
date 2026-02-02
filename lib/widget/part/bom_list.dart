import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/bom.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";

import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";

/*
 * Widget for displaying a Bill of Materials for a specified Part instance
 */
class BillOfMaterialsWidget extends StatefulWidget {
  const BillOfMaterialsWidget(
    this.part, {
    this.isParentComponent = true,
    Key? key,
  }) : super(key: key);

  final InvenTreePart part;

  final bool isParentComponent;

  @override
  _BillOfMaterialsState createState() => _BillOfMaterialsState();
}

class _BillOfMaterialsState extends RefreshableState<BillOfMaterialsWidget> {
  _BillOfMaterialsState();

  bool showFilterOptions = false;

  @override
  String getAppBarTitle() {
    if (widget.isParentComponent) {
      return L10().billOfMaterials;
    } else {
      return L10().usedIn;
    }
  }

  @override
  List<Widget> appBarActions(BuildContext context) => [
    IconButton(
      icon: Icon(TablerIcons.filter),
      onPressed: () async {
        setState(() {
          showFilterOptions = !showFilterOptions;
        });
      },
    ),
  ];

  @override
  Widget getBody(BuildContext context) {
    Map<String, String> filters = {};

    if (widget.isParentComponent) {
      filters["part"] = widget.part.pk.toString();
    } else {
      filters["uses"] = widget.part.pk.toString();
    }

    return Column(
      children: [
        ListTile(
          leading: InvenTreeAPI().getThumbnail(widget.part.thumbnail),
          title: Text(widget.part.fullname),
          subtitle: Text(
            widget.isParentComponent
                ? L10().billOfMaterials
                : L10().usedInDetails,
          ),
          trailing: Text(L10().quantity),
        ),
        Divider(thickness: 1.25),
        Expanded(
          child: PaginatedBomList(
            filters,
            isParentPart: widget.isParentComponent,
          ),
        ),
      ],
    );
  }
}

/*
 * Create a paginated widget displaying a list of BomItem objects
 */
class PaginatedBomList extends PaginatedSearchWidget {
  const PaginatedBomList(
    Map<String, String> filters, {
    this.isParentPart = true,
  }) : super(filters: filters);

  final bool isParentPart;

  @override
  String get searchTitle => L10().parts;

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
    "sub_part_active": {
      "label": L10().filterActive,
      "help_text": L10().filterActiveDetail,
      "tristate": true,
      "default": true,
    },
    "sub_part_assembly": {
      "label": L10().filterAssembly,
      "help_text": L10().filterAssemblyDetail,
    },
    "sub_part_virtual": {
      "label": L10().filterVirtual,
      "help_text": L10().filterVirtualDetail,
      "tristate": true,
      "default": true,
    },
  };

  @override
  Future<InvenTreePageResponse?> requestPage(
    int limit,
    int offset,
    Map<String, String> params,
  ) async {
    final page = await InvenTreeBomItem().listPaginated(
      limit,
      offset,
      filters: params,
    );

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {
    InvenTreeBomItem bomItem = model as InvenTreeBomItem;

    InvenTreePart? subPart = widget.isParentPart
        ? bomItem.subPart
        : bomItem.part;

    String title = subPart?.fullname ?? "error - no name";

    return ListTile(
      title: Text(title),
      subtitle: Text(bomItem.reference),
      trailing: Text(
        simpleNumberString(bomItem.quantity),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      leading: InvenTreeAPI().getThumbnail(subPart?.thumbnail ?? ""),
      onTap: subPart == null
          ? null
          : () async {
              showLoadingOverlay();
              var part = await InvenTreePart().get(subPart.pk);
              hideLoadingOverlay();

              if (part is InvenTreePart) {
                part.goToDetailPage(context);
              }
            },
    );
  }
}
