
import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/preferences.dart';

import 'package:InvenTree/widget/part_detail.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:InvenTree/widget/refreshable_state.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CategoryDisplayWidget extends StatefulWidget {

  CategoryDisplayWidget(this.category, {Key key}) : super(key: key);

  final InvenTreePartCategory category;

  final String title = "Category";

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState(category);
}


class _CategoryDisplayState extends RefreshableState<CategoryDisplayWidget> {

  @override
  String getAppBarTitle(BuildContext context) { return "Part Category"; }

  _CategoryDisplayState(this.category) {}

  // The local InvenTreePartCategory object
  final InvenTreePartCategory category;

  List<InvenTreePartCategory> _subcategories = List<InvenTreePartCategory>();

  List<InvenTreePart> _parts = List<InvenTreePart>();

  /*
   * Request data from the server
   */
  @override
  Future<void> request(BuildContext context) async {

    int pk = category?.pk ?? -1;

    // Request a list of sub-categories under this one
    InvenTreePartCategory().list(context, filters: {"parent": "$pk"}).then((var cats) {
      _subcategories.clear();

      for (var cat in cats) {
        if (cat is InvenTreePartCategory) {
          _subcategories.add(cat);
        }
      }

      // Update state
      setState(() {});
    });

    // Request a list of parts under this category
    InvenTreePart().list(context, filters: {"category": "$pk"}).then((var parts) {
      _parts.clear();

      for (var part in parts) {
        if (part is InvenTreePart) {
          _parts.add(part);
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
          title: Text("Part Categories"),
          subtitle: Text("Top level part category"),
        )
      );
    } else {
      return Card(
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text("${category.name}"),
              subtitle: Text("${category.description}"),
              trailing: IconButton(
                icon: FaIcon(FontAwesomeIcons.edit),
                onPressed: null,
              ),
            ),
            ListTile(
              title: Text("Parent Category"),
              subtitle: Text("${category.parentpathstring}"),
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
  Widget getBody(BuildContext context) {
    return ListView(
      children: <Widget>[
        getCategoryDescriptionCard(),
        ExpansionPanelList(
          expansionCallback: (int index, bool isExpanded) {
            setState(() {

              switch (index) {
                case 0:
                  InvenTreePreferences().expandCategoryList = !isExpanded;
                  break;
                case 1:
                  InvenTreePreferences().expandPartList = !isExpanded;
                  break;
                default:
                  break;
              }
            });
          },
          children: <ExpansionPanel> [
            ExpansionPanel(
              headerBuilder: (BuildContext context, bool isExpanded) {
                return ListTile(
                  title: Text("Subcategories"),
                  leading: FaIcon(FontAwesomeIcons.stream),
                  trailing: Text("${_subcategories.length}"),
                  onTap: () {
                    setState(() {
                      InvenTreePreferences().expandCategoryList = !InvenTreePreferences().expandCategoryList;
                    });
                  },
                  onLongPress: () {
                    // TODO - Context menu for e.g. creating a new PartCategory
                  },
                );
              },
              body: SubcategoryList(_subcategories),
              isExpanded: InvenTreePreferences().expandCategoryList && _subcategories.length > 0,
            ),
            ExpansionPanel(
              headerBuilder: (BuildContext context, bool isExpanded) {
                return ListTile(
                  title: Text("Parts"),
                  leading: FaIcon(FontAwesomeIcons.shapes),
                  trailing: Text("${_parts.length}"),
                  onTap: () {
                    setState(() {
                      InvenTreePreferences().expandPartList = !InvenTreePreferences().expandPartList;
                    });
                  },
                  onLongPress: () {
                    // TODO - Context menu for e.g. creating a new Part
                  },
                );
              },
              body: PartList(_parts),
              isExpanded: InvenTreePreferences().expandPartList && _parts.length > 0,
            )
          ],
        ),
      ]
    );
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
    return ListView.builder(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemBuilder: _build, itemCount: _categories.length);
  }
}


/*
 * Builder for displaying a list of Part objects
 */
class PartList extends StatelessWidget {
  final List<InvenTreePart> _parts;

  PartList(this._parts);

  void _openPart(BuildContext context, int pk) {
    // Attempt to load the part information
    InvenTreePart().get(context, pk).then((var part) {
      if (part is InvenTreePart) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
      }
    });
  }

  Widget _build(BuildContext context, int index) {
    InvenTreePart part;

    if (index < _parts.length) {
      part = _parts[index];
    }

    return ListTile(
      title: Text("${part.name}"),
      subtitle: Text("${part.description}"),
      leading: Image(
        image: InvenTreeAPI().getImage(part.thumbnail),
        width: 48,
      ),
      onTap: () {
        _openPart(context, part.pk);
      },
    );

  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemBuilder: _build, itemCount: _parts.length);
  }
}
