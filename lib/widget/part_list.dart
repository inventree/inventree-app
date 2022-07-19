import "package:flutter/material.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/api.dart";
import "package:inventree/preferences.dart";
import "package:inventree/l10.dart";


class PartList extends StatefulWidget {

  const PartList(this.filters, {this.title = ""});

  final String title;

  final Map<String, String> filters;

  @override
  _PartListState createState() => _PartListState(filters, title);
}


class _PartListState extends RefreshableState<PartList> {

  _PartListState(this.filters, this.title);

  final String title;

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => title.isNotEmpty ? title : L10().parts;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPartList(filters, true);
  }

}


class PaginatedPartList extends PaginatedSearchWidget {

  const PaginatedPartList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedPartListState createState() => _PaginatedPartListState();
}


class _PaginatedPartListState extends PaginatedSearchState<PaginatedPartList> {

  _PaginatedPartListState() : super();

  @override
  String get prefix => "part_";

  @override
  Map<String, String> get orderingOptions => {
    "name": L10().name,
    "in_stock": L10().stock,
    "IPN": L10().internalPartNumber,
  };

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "cascade": {
      "default": true,
      "label": L10().includeSubcategories,
      "help_text": L10().includeSubcategoriesDetail,
    },
    "active": {
      "label": L10().filterActive,
      "help_text": L10().filterActiveDetail,
    },
    "assembly": {
      "label": L10().filterAssembly,
      "help_text": L10().filterAssemblyDetail
    },
    "component": {
      "label": L10().filterComponent,
      "help_text": L10().filterComponentDetail,
    },
    "is_template": {
      "label": L10().filterTemplate,
      "help_text": L10().filterTemplateDetail
    },
    "virtual": {
      "label": L10().filterVirtual,
      "help_text": L10().filterVirtualDetail,
    },
    "has_stock": {
      "label": L10().filterInStock,
      "help_text": L10().filterInStockDetail,
    }
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final page = await InvenTreePart().listPaginated(limit, offset, filters: params);

    return page;
  }

  void _openPart(BuildContext context, int pk) {
    // Attempt to load the part information
    InvenTreePart().get(pk).then((var part) {
      if (part is InvenTreePart) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
      }
    });
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreePart part = model as InvenTreePart;

    return ListTile(
      title: Text(part.fullname),
      subtitle: Text(part.description),
      trailing: Text(part.stockString()),
      leading: InvenTreeAPI().getImage(
        part.thumbnail,
        width: 40,
        height: 40,
      ),
      onTap: () {
        _openPart(context, part.pk);
      },
    );
  }
}