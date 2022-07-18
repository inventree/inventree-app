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
    return PaginatedPartList(filters);
  }

}


class PaginatedPartList extends StatefulWidget {

  const PaginatedPartList(this.filters, {this.searchEnabled = true});

  final Map<String, String> filters;

  final bool searchEnabled;

  @override
  _PaginatedPartListState createState() => _PaginatedPartListState(filters, searchEnabled);
}


class _PaginatedPartListState extends PaginatedSearchState<PaginatedPartList> {

  _PaginatedPartListState(Map<String, String> filters, bool searchEnabled) : super(filters, searchEnabled);

  @override
  String get prefix => "part_";

  @override
  Map<String, String> get orderingOptions => {
    "name": L10().name,
    "in_stock": L10().stock,
    "IPN": L10().internalPartNumber,
  };

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final bool cascade = await InvenTreeSettingsManager().getBool(INV_PART_SUBCATEGORY, true);

    params["cascade"] = "${cascade}";

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