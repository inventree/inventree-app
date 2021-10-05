import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/category_display.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/l10.dart";

class PartCategoryList extends StatefulWidget {

  const PartCategoryList(this.filters);

  final Map<String, String> filters;

  @override
  _PartCategoryListState createState() => _PartCategoryListState(filters);

}


class _PartCategoryListState extends RefreshableState<PartCategoryList> {

  _PartCategoryListState(this.filters);

  final Map<String, String> filters;

  @override
  String getAppBarTitle(BuildContext context) => L10().partCategories;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPartCategoryList(filters);
  }
}


class PaginatedPartCategoryList extends StatefulWidget {

  const PaginatedPartCategoryList(this.filters);

  final Map<String, String> filters;

  @override
  _PaginatedPartCategoryListState createState() => _PaginatedPartCategoryListState(filters);
}


class _PaginatedPartCategoryListState extends PaginatedSearchState<PaginatedPartCategoryList> {

  _PaginatedPartCategoryListState(Map<String, String> filters) : super(filters);

  @override
  Future<InvenTreePageResponse?> requestPage(int limit, int offset, Map<String, String> params) async {

    final page = await InvenTreePartCategory().listPaginated(limit, offset, filters: params);

    return page;
  }

  @override
  Widget buildItem(BuildContext context, InvenTreeModel model) {

    InvenTreePartCategory category = model as InvenTreePartCategory;

    return ListTile(
      title: Text(category.name),
      subtitle: Text(category.pathstring),
      trailing: Text("${category.partcount}"),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryDisplayWidget(category)
          )
        );
      },
    );
  }
}