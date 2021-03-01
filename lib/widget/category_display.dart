
import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/preferences.dart';
import 'package:InvenTree/widget/progress.dart';
import 'package:InvenTree/widget/search.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/widget/fields.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:InvenTree/widget/refreshable_state.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class CategoryDisplayWidget extends StatefulWidget {

  CategoryDisplayWidget(this.category, {Key key}) : super(key: key);

  final InvenTreePartCategory category;

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState(category);
}


class _CategoryDisplayState extends RefreshableState<CategoryDisplayWidget> {

  final _editCategoryKey = GlobalKey<FormState>();

  @override
  String getAppBarTitle(BuildContext context) => I18N.of(context).partCategory;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.search),
          onPressed: () {

            Map<String, String> filters = {};

            if (category != null) {
              filters["category"] = "${category.pk}";
            }

            showSearch(
                context: context,
                delegate: PartSearchDelegate(context, filters: filters)
            );
          }
        )
    );

    if ((category != null) && InvenTreeAPI().checkPermission('part_category', 'change')) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.edit),
          tooltip: I18N.of(context).edit,
          onPressed: _editCategoryDialog,
        )
      );
    }

    return actions;

  }

  void _editCategory(Map<String, String> values) async {

    final bool result = await category.update(context, values: values);

    showSnackIcon(
      result ? "Category edited" : "Category editing failed",
      success: result
    );

    refresh();
  }

  void _editCategoryDialog() {

    var _name;
    var _description;

    showFormDialog(
      I18N.of(context).editCategory,
      key: _editCategoryKey,
      callback: () {
        _editCategory({
          "name": _name,
          "description": _description
        });
      },
      fields: <Widget>[
        StringField(
          label: I18N.of(context).name,
          initial: category.name,
          onSaved: (value) => _name = value
        ),
        StringField(
          label: I18N.of(context).description,
          initial: category.description,
          onSaved: (value) => _description = value
        )
      ]
    );
  }

  _CategoryDisplayState(this.category) {}

  // The local InvenTreePartCategory object
  final InvenTreePartCategory category;

  List<InvenTreePartCategory> _subcategories = List<InvenTreePartCategory>();

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh();
  }

  @override
  Future<void> request(BuildContext context) async {

    int pk = category?.pk ?? -1;

    // Update the category
    if (category != null) {
      await category.reload(context);
    }

    // Request a list of sub-categories under this one
    await InvenTreePartCategory().list(context, filters: {"parent": "$pk"}).then((var cats) {
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

  Widget getCategoryDescriptionCard() {
    if (category == null) {
      return Card(
        child: ListTile(
          title: Text("Top level part category"),
        )
      );
    } else {
      return Card(
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text("${category.name}",
                  style: TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Text("${category.description}"),
            ),
            Divider(),
            ListTile(
              title: Text(I18N.of(context).parentCategory),
              subtitle: Text("${category.parentpathstring}"),
              leading: FaIcon(FontAwesomeIcons.levelUpAlt),
              onTap: () {
                if (category.parentId < 0) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
                } else {
                  // TODO - Refactor this code into the InvenTreePart class
                  InvenTreePartCategory().get(context, category.parentId).then((var cat) {
                    if (cat is InvenTreePartCategory) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(cat)));
                    }
                  });
                }
              },
            )
          ]
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
          label: I18N.of(context).details,
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.shapes),
          label: I18N.of(context).parts,
        ),
        // TODO - Add the "actions" item back in
        /*
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          label: I18N.of(context).actions
        ),
         */
      ]
    );
  }

  List<Widget> detailTiles() {
    List<Widget> tiles = <Widget>[
      getCategoryDescriptionCard(),
      ListTile(
        title: Text(
          I18N.of(context).subcategories,
          style: TextStyle(fontWeight: FontWeight.bold)
        ),
        trailing: _subcategories.isNotEmpty ? Text("${_subcategories.length}") : null,
      ),
    ];

    if (loading) {
      tiles.add(progressIndicator());
    } else if (_subcategories.length == 0) {
      tiles.add(ListTile(
        title: Text("No Subcategories"),
        subtitle: Text("No subcategories available")
      ));
    } else {
      tiles.add(SubcategoryList(_subcategories));
    }

    return tiles;
  }

  List<Widget> actionTiles() {

    List<Widget> tiles = [
      getCategoryDescriptionCard(),
      ListTile(
        title: Text(I18N.of(context).actions,
          style: TextStyle(fontWeight: FontWeight.bold)
        )
      )
    ];

    // TODO - Actions!

    return tiles;
  }

  @override
  Widget getBody(BuildContext context) {

    switch (tabIndex) {
      case 0:
        return ListView(
          children: detailTiles()
        );
      case 1:
        return PaginatedPartList(category?.pk ?? null);
      case 2:
        return ListView(
          children: actionTiles()
        );
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
    InvenTreePartCategory().get(context, pk).then((var cat) {
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


/**
 * Widget for displaying a list of Part objects within a PartCategory display.
 *
 * Uses server-side pagination for snappy results
 */

class PaginatedPartList extends StatefulWidget {

  final int categoryId;

  PaginatedPartList(this.categoryId);

  @override
  _PaginatedPartListState createState() => _PaginatedPartListState(categoryId);
}


class _PaginatedPartListState extends State<PaginatedPartList> {

  static const _pageSize = 25;

  final int categoryId;

  _PaginatedPartListState(this.categoryId);

  final PagingController<int, InvenTreePart> _pagingController = PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  Future<void> _fetchPage(int pageKey) async {
    try {

      final page = await InvenTreePart().listPaginated(_pageSize, pageKey, filters: {"category": "${categoryId}"});
      final isLastPage = page.length < _pageSize;

      // Construct a list of part objects
      List<InvenTreePart> parts = [];

      for (var result in page.results) {
        if (result is InvenTreePart) {
          parts.add(result);
        }
      }

      if (isLastPage) {
        _pagingController.appendLastPage(parts);
      } else {
        final int nextPageKey = pageKey + page.length;
        _pagingController.appendPage(parts, nextPageKey);
      }

    } catch (error) {
      print("Error! - ${error.toString()}");
      _pagingController.error = error;
    }
  }

  void _openPart(BuildContext context, int pk) {
    // Attempt to load the part information
    InvenTreePart().get(context, pk).then((var part) {
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

  @override
  Widget build(BuildContext context) {
    return PagedListView<int, InvenTreePart>.separated(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<InvenTreePart>(
          itemBuilder: (context, item, index) {
            return _buildPart(context, item);
          }
        ),
        separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }
}
