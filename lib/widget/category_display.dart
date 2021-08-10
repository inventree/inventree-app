
import 'package:inventree/api.dart';
import 'package:inventree/app_colors.dart';
import 'package:inventree/app_settings.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/inventree/sentry.dart';
import 'package:inventree/widget/progress.dart';

import 'package:inventree/l10.dart';

import 'package:inventree/widget/part_detail.dart';
import 'package:inventree/widget/refreshable_state.dart';
import 'package:inventree/widget/paginator.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../api_form.dart';

class CategoryDisplayWidget extends StatefulWidget {

  CategoryDisplayWidget(this.category, {Key? key}) : super(key: key);

  final InvenTreePartCategory? category;

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState(category);
}


class _CategoryDisplayState extends RefreshableState<CategoryDisplayWidget> {


  @override
  String getAppBarTitle(BuildContext context) => L10().partCategory;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if ((category != null) && InvenTreeAPI().checkPermission('part_category', 'change')) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.edit),
          tooltip: L10().edit,
          onPressed: () {
            _editCategoryDialog(context);
          },
        )
      );
    }

    return actions;

  }

  void _editCategoryDialog(BuildContext context) {
    final _cat = category;

    // Cannot edit top-level category
    if (_cat == null) {
      return;
    }

    _cat.editForm(
        context,
        L10().editCategory,
        onSuccess: (data) async {
          refresh();
        }
    );
  }

  _CategoryDisplayState(this.category);

  // The local InvenTreePartCategory object
  final InvenTreePartCategory? category;

  List<InvenTreePartCategory> _subcategories = [];

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh();
  }

  @override
  Future<void> request() async {

    int pk = category?.pk ?? -1;

    // Update the category
    if (category != null) {
      await category!.reload();
    }

    // Request a list of sub-categories under this one
    await InvenTreePartCategory().list(filters: {"parent": "$pk"}).then((var cats) {
      _subcategories.clear();

      for (var cat in cats) {
        if (cat is InvenTreePartCategory) {
          _subcategories.add(cat);
        }
      }

      // Update state
      setState(() {});
    });
  }

  Widget getCategoryDescriptionCard({bool extra = true}) {
    if (category == null) {
      return Card(
        child: ListTile(
          title: Text(L10().partCategoryTopLevel)
        )
      );
    } else {

      List<Widget> children = [
        ListTile(
          title: Text("${category?.name}",
              style: TextStyle(fontWeight: FontWeight.bold)
          ),
          subtitle: Text("${category?.description}"),
        ),
      ];

      if (extra) {
        children.add(
            ListTile(
              title: Text(L10().parentCategory),
              subtitle: Text("${category?.parentpathstring}"),
              leading: FaIcon(
                FontAwesomeIcons.levelUpAlt,
                color: COLOR_CLICK,
              ),
              onTap: () {
                if (category == null || ((category?.parentId ?? 0) < 0)) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
                } else {
                  // TODO - Refactor this code into the InvenTreePart class
                  InvenTreePartCategory().get(category?.parentId ?? -1).then((var cat) {
                    if (cat is InvenTreePartCategory) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(cat)));
                    }
                  });
                }
              },
            )
        );
      }

      return Card(
        child: Column(
          children: children
        ),
      );
    }
  }

  @override
  Widget getBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: tabIndex,
      onTap: onTabSelectionChanged,
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.sitemap),
          label: L10().details,
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.shapes),
          label: L10().parts,
        ),
        // TODO - Add the "actions" item back in
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          label: L10().actions
        ),
      ]
    );
  }

  List<Widget> detailTiles() {
    List<Widget> tiles = <Widget>[
      getCategoryDescriptionCard(),
      ListTile(
        title: Text(
          L10().subcategories,
          style: TextStyle(fontWeight: FontWeight.bold)
        ),
        trailing: _subcategories.isNotEmpty ? Text("${_subcategories.length}") : null,
      ),
    ];

    if (loading) {
      tiles.add(progressIndicator());
    } else if (_subcategories.length == 0) {
      tiles.add(ListTile(
        title: Text(L10().noSubcategories),
        subtitle: Text(L10().noSubcategoriesAvailable)
      ));
    } else {
      tiles.add(SubcategoryList(_subcategories));
    }

    return tiles;
  }

  Future<void> _newCategory(BuildContext context) async {

    int pk = category?.pk ?? -1;

    InvenTreePartCategory().createForm(
      context,
      L10().categoryCreate,
      data: {
        "parent": (pk > 0) ? pk : null,
      },
      onSuccess: (data) async {
        
        if (data.containsKey("pk")) {
          var new_cat = InvenTreePartCategory.fromJson(data);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryDisplayWidget(new_cat)
            )
          );
        } else {
          refresh();
        }
      }
    );
  }

  Future<void> _newPart() async {

  }

  List<Widget> actionTiles(BuildContext context) {

    List<Widget> tiles = [
      getCategoryDescriptionCard(extra: false),
    ];

    tiles.add(
      ListTile(
        title: Text(L10().categoryCreate),
        subtitle: Text(L10().categoryCreateDetail),
        leading: FaIcon(FontAwesomeIcons.sitemap, color: COLOR_CLICK),
        onTap: () async {
          _newCategory(context);
        },
      )
    );

    if (category != null) {
      tiles.add(
          ListTile(
            title: Text(L10().partCreate),
            subtitle: Text(L10().partCreateDetail),
            leading: FaIcon(FontAwesomeIcons.shapes, color: COLOR_CLICK),
            onTap: _newPart,
          )
      );
    }

    return tiles;
  }

  int partCount = 0;

  @override
  Widget getBody(BuildContext context) {

    switch (tabIndex) {
      case 0:
        return ListView(
          children: detailTiles()
        );
      case 1:
        return PaginatedPartList(
          {"category": "${category?.pk ?? null}"},
        );
      case 2:
        return ListView(
          children: actionTiles(context)
        );
      default:
        return ListView();
    }
  }
}


/*
 * Builder for displaying a list of PartCategory objects
 */
class SubcategoryList extends StatelessWidget {
  final List<InvenTreePartCategory> _categories;

  SubcategoryList(this._categories);

  void _openCategory(BuildContext context, int pk) {

    // Attempt to load the sub-category.
    InvenTreePartCategory().get(pk).then((var cat) {
      if (cat is InvenTreePartCategory) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(cat)));
      }
    });
  }

  Widget _build(BuildContext context, int index) {
    InvenTreePartCategory cat = _categories[index];

    return ListTile(
      title: Text("${cat.name}"),
      subtitle: Text("${cat.description}"),
      trailing: Text("${cat.partcount}"),
      onTap: () {
        _openCategory(context, cat.pk);
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        separatorBuilder: (_, __) => const Divider(height: 3),
        itemBuilder: _build, itemCount: _categories.length);
  }
}


/*
 * Widget for displaying a list of Part objects within a PartCategory display.
 *
 * Uses server-side pagination for snappy results
 */

class PaginatedPartList extends StatefulWidget {

  final Map<String, String> filters;

  Function(int)? onTotalChanged;

  PaginatedPartList(this.filters, {this.onTotalChanged});

  @override
  _PaginatedPartListState createState() => _PaginatedPartListState(filters, onTotalChanged);
}


class _PaginatedPartListState extends State<PaginatedPartList> {

  static const _pageSize = 25;

  String _searchTerm = "";

  Function(int)? onTotalChanged;

  final Map<String, String> filters;

  _PaginatedPartListState(this.filters, this.onTotalChanged);

  final PagingController<int, InvenTreePart> _pagingController = PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });

    super.initState();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  int resultCount = 0;

  Future<void> _fetchPage(int pageKey) async {
    try {

      Map<String, String> params = filters;

      params["search"] = _searchTerm;

      final bool cascade = await InvenTreeSettingsManager().getValue("partSubcategory", true);
      params["cascade"] = "${cascade}";

      final page = await InvenTreePart().listPaginated(_pageSize, pageKey, filters: params);
      int pageLength = page?.length ?? 0;
      int pageCount = page?.count ?? 0;

      final isLastPage = pageLength < _pageSize;

      // Construct a list of part objects
      List<InvenTreePart> parts = [];

      if (page != null) {
        for (var result in page.results) {
          if (result is InvenTreePart) {
            parts.add(result);
          }
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(parts);
      } else {
        final int nextPageKey = pageKey + pageLength;
        _pagingController.appendPage(parts, nextPageKey);
      }

      if (onTotalChanged != null) {
        onTotalChanged!(pageCount);
      }

      setState(() {
        resultCount = pageCount;
      });

    } catch (error, stackTrace) {
      print("Error! - ${error.toString()}");
      _pagingController.error = error;

      sentryReportError(error, stackTrace);
    }
  }

  void _openPart(BuildContext context, int pk) {
    // Attempt to load the part information
    InvenTreePart().get(pk).then((var part) {
      if (part is InvenTreePart) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
      }
    });
  }

  Widget _buildPart(BuildContext context, InvenTreePart part) {
    return ListTile(
      title: Text(part.fullname),
      subtitle: Text("${part.description}"),
      trailing: Text("${part.inStockString}"),
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

  final TextEditingController searchController = TextEditingController();

  void updateSearchTerm() {

    print("Search Term: '${_searchTerm}'");

    _searchTerm = searchController.text;
    _pagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        PaginatedSearchWidget(searchController, updateSearchTerm, resultCount),
        Expanded(
          child: CustomScrollView(
            shrinkWrap: true,
            physics: ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            slivers: [
              PagedSliverList.separated(
                  pagingController: _pagingController,
                  builderDelegate: PagedChildBuilderDelegate<InvenTreePart>(
                    itemBuilder: (context, item, index) {
                      return _buildPart(context, item);
                    },
                    noItemsFoundIndicatorBuilder: (context) {
                      return NoResultsWidget(L10().partNoResults);
                    },
                  ),
                separatorBuilder: (context, index) => const Divider(height: 1),
              )
            ],
          )
        )
      ],
    );
  }
}
