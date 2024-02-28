import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";

import "package:inventree/widget/part/category_list.dart";
import "package:inventree/widget/part/part_list.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/part/part_detail.dart";
import "package:inventree/widget/refreshable_state.dart";


class CategoryDisplayWidget extends StatefulWidget {

  const CategoryDisplayWidget(this.category, {Key? key}) : super(key: key);

  final InvenTreePartCategory? category;

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState();
}


class _CategoryDisplayState extends RefreshableState<CategoryDisplayWidget> {

  _CategoryDisplayState();

  @override
  String getAppBarTitle() => L10().partCategory;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.category != null) {
      if (InvenTreePartCategory().canEdit) {
        actions.add(
          IconButton(
            icon:  Icon(Icons.edit_square),
            tooltip: L10().editCategory,
            onPressed: () {
              _editCategoryDialog(context);
            },
          )
        );
      }
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreePart().canCreate) {
     actions.add(
       SpeedDialChild(
         child: FaIcon(FontAwesomeIcons.shapes),
         label: L10().partCreateDetail,
         onTap: _newPart,
       )
     );
    }

    if (InvenTreePartCategory().canCreate) {
      actions.add(
        SpeedDialChild(
          child: FaIcon(FontAwesomeIcons.sitemap),
          label: L10().categoryCreateDetail,
          onTap: () {
            _newCategory(context);
          }
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
                color: COLOR_ACTION,
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
  List<Widget> getTabIcons(BuildContext context) {

    return [
      Tab(text: L10().details),
      Tab(text: L10().parts),
    ];
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    return [
      Column(children: detailTiles()),
      Column(children: partsTiles()),
    ];
  }

  // Construct the "details" panel
  List<Widget> detailTiles() {

    Map<String, String> filters = {};

    int? parent = widget.category?.pk;

    if (parent != null) {
      filters["parent"] = parent.toString();
    } else if (api.supportsNullTopLevelFiltering) {
      filters["parent"] = "null";
    }

    List<Widget> tiles = <Widget>[
      getCategoryDescriptionCard(),
      Expanded(
        child: PaginatedPartCategoryList(
          filters,
          title: L10().subcategories,
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
      Expanded(
        child: PaginatedPartList(filters),
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
}
