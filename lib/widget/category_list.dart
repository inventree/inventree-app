import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/category_display.dart";
import "package:inventree/widget/paginator.dart";
import "package:inventree/widget/refreshable_state.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";

class PartCategoryList extends StatefulWidget {

  const PartCategoryList(this.filters);

  final Map<String, String> filters;

  @override
  _PartCategoryListState createState() => _PartCategoryListState();

}


class _PartCategoryListState extends RefreshableState<PartCategoryList> {

  _PartCategoryListState();

  bool showFilterOptions = false;

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
  String getAppBarTitle(BuildContext context) => L10().partCategories;

  @override
  Widget getBody(BuildContext context) {
    return PaginatedPartCategoryList(widget.filters, showFilterOptions);
  }
}

class PaginatedPartCategoryList extends PaginatedSearchWidget {

  const PaginatedPartCategoryList(Map<String, String> filters, bool showSearch) : super(filters: filters, showSearch: showSearch);

  @override
  _PaginatedPartCategoryListState createState() => _PaginatedPartCategoryListState();
}


class _PaginatedPartCategoryListState extends PaginatedSearchState<PaginatedPartCategoryList> {

  // _PaginatedPartCategoryListState(Map<String, String> filters, bool searchEnabled) : super(filters, searchEnabled);

  @override
  String get prefix => "category_";

  @override
  Map<String, Map<String, dynamic>> get filterOptions => {
    "cascade": {
      "default": false,
      "label": L10().includeSubcategories,
      "help_text": L10().includeSubcategoriesDetail,
      "tristate": false,
    }
  };

  @override
  Map<String, String> get orderingOptions {

    Map<String, String> options = {
      "name": L10().name,
      "level": L10().level,
    };

    // Note: API v69 changed 'parts' to 'part_count'
    if (InvenTreeAPI().apiVersion >= 69) {
      options["part_count"] = L10().parts;
    } else {
      options["parts"] = L10().parts;
    }

    return options;
  }

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
      leading: category.customIcon,
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