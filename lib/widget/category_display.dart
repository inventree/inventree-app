
import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/part.dart';

import 'package:InvenTree/widget/part_display.dart';
import 'package:InvenTree/widget/drawer.dart';

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


class _CategoryDisplayState extends State<CategoryDisplayWidget> {

  _CategoryDisplayState(this.category) {
    _requestData();
  }

  // The local InvenTreePartCategory object
  final InvenTreePartCategory category;

  List<InvenTreePartCategory> _subcategories = List<InvenTreePartCategory>();

  List<InvenTreePart> _parts = List<InvenTreePart>();

  String get _titleString {

    if (category == null) {
      return "Part Categories";
    } else {
      return "Part Category - ${category.name}";
    }
  }

  /*
   * Request data from the server
   */
  void _requestData() {

    int pk = category?.pk ?? -1;

    // Request a list of sub-categories under this one
    InvenTreePartCategory().list(filters: {"parent": "$pk"}).then((var cats) {
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
    InvenTreePart().list(filters: {"category": "$pk"}).then((var parts) {
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

  bool _subcategoriesExpanded = false;
  bool _partListExpanded = true;

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
          child: ListTile(
            title: Text("${category.name}"),
            subtitle: Text("${category.description}"),
            trailing: IconButton(
              icon: FaIcon(FontAwesomeIcons.edit),
              onPressed: null,
            ),
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleString),
      ),
      drawer: new InvenTreeDrawer(context),
      body: ListView(
          //mainAxisAlignment: MainAxisAlignment.start,
          //mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            getCategoryDescriptionCard(),
            ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                print("callback!");
                setState(() {

                  switch (index) {
                    case 0:
                      _subcategoriesExpanded = !isExpanded;
                      break;
                    case 1:
                      _partListExpanded = !isExpanded;
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
                      trailing: Text("${_subcategories.length}"),
                      onTap: () {
                        setState(() {
                          _subcategoriesExpanded = !_subcategoriesExpanded;
                        });
                      },
                    );
                  },
                  body: SubcategoryList(_subcategories),
                  isExpanded: _subcategoriesExpanded,
                ),
                ExpansionPanel(
                  headerBuilder: (BuildContext context, bool isExpanded) {
                    return ListTile(
                      title: Text("Parts"),
                      trailing: Text("${_parts.length}"),
                      onTap: () {
                        setState(() {
                          _partListExpanded = !_partListExpanded;
                        });
                      },
                    );
                  },
                  body: PartList(_parts),
                  isExpanded: _partListExpanded,
                )
              ],
            ),
          ]
        )
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
      onTap: () {
        _openCategory(context, cat.pk);
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        shrinkWrap: true,
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
    InvenTreePart().get(pk).then((var part) {
      if (part is InvenTreePart) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => PartDisplayWidget(part)));
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
        itemBuilder: _build, itemCount: _parts.length);
  }
}
