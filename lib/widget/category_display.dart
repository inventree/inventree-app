import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";

import "package:inventree/widget/category_list.dart";
import "package:inventree/widget/part_list.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/refreshable_state.dart";


class CategoryDisplayWidget extends StatefulWidget {

  const CategoryDisplayWidget(this.category, {Key? key}) : super(key: key);

  final InvenTreePartCategory? category;

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState();
}


class _CategoryDisplayState extends RefreshableState<CategoryDisplayWidget> {

  _CategoryDisplayState();

  bool showFilterOptions = false;

  @override
  String getAppBarTitle(BuildContext context) => L10().partCategory;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if ((widget.category != null) && InvenTreeAPI().checkPermission("part_category", "change")) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.penToSquare),
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
    final _cat = widget.category;

    // Cannot edit top-level category
    if (_cat == null) {
      return;
    }

    _cat.editForm(
        context,
        L10().editCategory,
        onSuccess: (data) async {
          refresh(context);
          showSnackIcon(L10().categoryUpdated, success: true);
        }
    );
  }

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh(context);
  }

  @override
  Future<void> request(BuildContext context) async {

    // Update the category
    if (widget.category != null) {
      final bool result = await widget.category?.reload() ?? false;

      if (!result) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget getCategoryDescriptionCard({bool extra = true}) {
    if (widget.category == null) {
      return Card(
        child: ListTile(
          leading: FaIcon(FontAwesomeIcons.shapes),
          title: Text(
            L10().partCategoryTopLevel,
            style: TextStyle(fontStyle: FontStyle.italic),
          )
        )
      );
    } else {

      List<Widget> children = [
        ListTile(
          title: Text("${widget.category?.name}",
              style: TextStyle(fontWeight: FontWeight.bold)
          ),
          subtitle: Text("${widget.category?.description}"),
          leading: widget.category!.customIcon ?? FaIcon(FontAwesomeIcons.sitemap),
        ),
      ];

      if (extra) {
        children.add(
            ListTile(
              title: Text(L10().parentCategory),
              subtitle: Text("${widget.category?.parentPathString}"),
              leading: FaIcon(
                FontAwesomeIcons.turnUp,
                color: COLOR_CLICK,
              ),
              onTap: () async {

                int parentId = widget.category?.parentId ?? -1;

                if (parentId < 0) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
                } else {

                  showLoadingOverlay(context);
                  var cat = await InvenTreePartCategory().get(parentId);
                  hideLoadingOverlay();

                  if (cat is InvenTreePartCategory) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(cat)));
                  }
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
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          label: L10().actions
        ),
      ]
    );
  }

  // Construct the "details" panel
  List<Widget> detailTiles() {

    List<Widget> tiles = <Widget>[
      getCategoryDescriptionCard(),
      ListTile(
        title: Text(
          L10().subcategories,
          style: TextStyle(fontWeight: FontWeight.bold)
        ),
        trailing: GestureDetector(
          child: FaIcon(FontAwesomeIcons.filter),
          onTap: () async {
            setState(() {
              showFilterOptions = !showFilterOptions;
            });
          },
        )
      ),
      Expanded(
        child: PaginatedPartCategoryList(
            {
              "parent": widget.category?.pk.toString() ?? "null"
            },
            showFilterOptions,
        ),
        flex: 10,
      )
    ];

    return tiles;
  }

  // Construct the "parts" panel
  List<Widget> partsTiles() {

    Map<String, String> filters = {
      "category": widget.category?.pk.toString() ?? "null",
    };

    return [
      getCategoryDescriptionCard(extra: false),
      ListTile(
        title: Text(
          L10().parts,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: GestureDetector(
          child: FaIcon(FontAwesomeIcons.filter),
          onTap: () async {
            setState(() {
              showFilterOptions = !showFilterOptions;
            });
          },
        ),
      ),
      Expanded(
        child: PaginatedPartList(
          filters,
          showFilterOptions,
        ),
        flex: 10,
      )
    ];
  }

  Future<void> _newCategory(BuildContext context) async {

    int pk = widget.category?.pk ?? -1;

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
          refresh(context);
        }
      }
    );
  }

  Future<void> _newPart() async {

    int pk = widget.category?.pk ?? -1;

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

      if (widget.category != null) {
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
          leading: FaIcon(FontAwesomeIcons.userXmark),
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
        return Column(
            children: detailTiles()
        );
      case 1:
        return Column(
          children: partsTiles()
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
