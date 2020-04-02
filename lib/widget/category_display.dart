
import 'package:InvenTree/inventree/part.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CategoryDisplayWidget extends StatefulWidget {

  CategoryDisplayWidget(int catId, {this.category, Key key}) : categoryId = catId, super(key: key);

  InvenTreePartCategory category = null;

  final String title = "Category";

  final int categoryId;

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState(categoryId, category: category);
}


class _CategoryDisplayState extends State<CategoryDisplayWidget> {

  _CategoryDisplayState(int id, {this.category}) : categoryId = id {
    _requestData();
  }

  final int categoryId;

  // The local InvenTreePartCategory object
  InvenTreePartCategory category = null;

  List<InvenTreePartCategory> subcategories = List<InvenTreePartCategory>();

  List<InvenTreePart> parts = List<InvenTreePart>();

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

    // Request a list of sub-categories under this one
    InvenTreePartCategory().list(filters: {"parent": "$categoryId"}).then((var cats) {
      subcategories.clear();

      print("Returned categories: ${cats.length}");

      for (var cat in cats) {
        if (cat is InvenTreePartCategory) {
          subcategories.add(cat);
        }
      }

      // Update state
      setState(() {});
    });

    // Request a list of parts under this category
    InvenTreePart().list(filters: {"category": "$categoryId"}).then((var parts) {
      parts.clear();

      print("Returned parts: ${parts.length}");

      for (var part in parts) {
        if (part is InvenTreePart) {
          parts.add(part);
          print("Adding part: ${part.name}");
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
              "Subcategories",
            ),
            Expanded(child: SubcategoryList(subcategories)),
            Divider(),
            Text("Parts"),
            Expanded(child: PartList(parts)),
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
        print("Found cat: <${cat.pk}> : ${cat.name} - ${cat.description}");

        Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(pk, category: cat)));
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

  Widget _build(BuildContext context, int index) {
    InvenTreePart part;

    if (index < _parts.length) {
      part = _parts[index];
    }

    return Card(
      child: Column(
        children: <Widget> [
          Text('${part.name} - ${part.description}'),
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemBuilder: _build, itemCount: _parts.length);
  }
}
