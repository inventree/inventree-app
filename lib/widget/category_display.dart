import "package:flutter/cupertino.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/part_list.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/refreshable_state.dart";


class CategoryDisplayWidget extends StatefulWidget {

  const CategoryDisplayWidget(this.category, {Key? key}) : super(key: key);

  final InvenTreePartCategory? category;

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState(category);
}


class _CategoryDisplayState extends RefreshableState<CategoryDisplayWidget> {

  _CategoryDisplayState(this.category);

  @override
  String getAppBarTitle(BuildContext context) => L10().partCategory;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if ((category != null) && InvenTreeAPI().checkPermission("part_category", "change")) {
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
          showSnackIcon(L10().categoryUpdated, success: true);
        }
    );
  }

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
    } else if (_subcategories.isEmpty) {
      tiles.add(ListTile(
        title: Text(L10().noSubcategories),
        subtitle: Text(
            L10().noSubcategoriesAvailable,
            style: TextStyle(fontStyle: FontStyle.italic)
        )
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
      onSuccess: (result) async {

        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var cat = InvenTreePartCategory.fromJson(data);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryDisplayWidget(cat)
            )
          );
        } else {
          refresh();
        }
      }
    );
  }

  Future<void> _newPart() async {

    int pk = category?.pk ?? -1;

    InvenTreePart().createForm(
      context,
      L10().partCreate,
      data: {
        "category": (pk > 0) ? pk : null
      },
      onSuccess: (result) async {

        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var part = InvenTreePart.fromJson(data);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PartDetailWidget(part)
            )
          );
        }
      }
    );
  }

  List<Widget> actionTiles(BuildContext context) {

    List<Widget> tiles = [
      getCategoryDescriptionCard(extra: false),
    ];

    if (InvenTreeAPI().checkPermission("part", "add")) {
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
    }

    if (tiles.isEmpty) {
      tiles.add(
        ListTile(
          title: Text(
            L10().actionsNone
          ),
          subtitle: Text(
            L10().permissionAccountDenied,
          ),
          leading: FaIcon(FontAwesomeIcons.userTimes),
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
          {
            "category": "${category?.pk ?? 'null'}"
          },
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

  const SubcategoryList(this._categories);

  final List<InvenTreePartCategory> _categories;

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
