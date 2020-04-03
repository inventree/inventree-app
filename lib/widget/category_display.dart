
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/part_display.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
      return "Part Category '${category.name}'";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleString),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Subcategories - ${_subcategories.length}",
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(child: SubcategoryList(_subcategories)),
            Divider(),
            Text("Parts - ${_parts.length}",
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(child: PartList(_parts)),
            Spacer(),
          ]
        )
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
    InvenTreePartCategory cat;

    if (index < _categories.length) {
      cat = _categories[index];
    }

    return Card(
      child: InkWell(
        child: Column(
          children: <Widget>[
            Text('${cat.name} - ${cat.description}'),
          ],
        ),
        onTap: () {
          _openCategory(context, cat.pk);
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemBuilder: _build, itemCount: _categories.length);
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

    return Card(
      child: InkWell(
        child: Column(
          children: <Widget> [
            Text('${part.name} - ${part.description}'),
          ]
        ),
        onTap: () {
          _openPart(context, part.pk);
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemBuilder: _build, itemCount: _parts.length);
  }
}
