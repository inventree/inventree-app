import 'dart:convert';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/stock.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'model.dart';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class InvenTreePartCategory extends InvenTreeModel {

  @override
  String NAME = "PartCategory";

  @override
  String URL = "part/category/";

  @override
  Map<String, String> defaultListFilters() {
    var filters = new Map<String, String>();

    filters["active"] = "true";
    filters["cascade"] = "false";

    return filters;
  }

  String get pathstring => jsondata['pathstring'] ?? '';

  String get parentpathstring {
    // TODO - Drive the refactor tractor through this
    List<String> psplit = pathstring.split("/");

    if (psplit.length > 0) {
      psplit.removeLast();
    }

    String p = psplit.join("/");

    if (p.isEmpty) {
      p = "Top level part category";
    }

    return p;
  }

  int get partcount => jsondata['parts'] ?? 0;

  InvenTreePartCategory() : super();

  InvenTreePartCategory.fromJson(Map<String, dynamic> json) : super.fromJson(json) {

  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var cat = InvenTreePartCategory.fromJson(json);

    // TODO ?

    return cat;
  }
}


class InvenTreePartTestTemplate extends InvenTreeModel {

  @override
  String NAME = "PartTestTemplate";

  @override
  String URL = "part/test-template/";

  String get key => jsondata['key'] ?? '';

  String get testName => jsondata['test_name'] ?? '';

  String get description => jsondata['description'] ?? '';

  bool get required => jsondata['required'] ?? false;

  bool get requiresValue => jsondata['requires_value'] ?? false;

  bool get requiresAttachment => jsondata['requires_attachment'] ?? false;

  InvenTreePartTestTemplate() : super();

  InvenTreePartTestTemplate.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var template = InvenTreePartTestTemplate.fromJson(json);

    return template;
  }

  bool passFailStatus() {
    var result = latestResult();

    if (result == null) {
      return null;
    }

    return result.result;
  }

  // List of test results associated with this template
  List<InvenTreeStockItemTestResult> results = [];

  // Return the most recent test result recorded against this template
  InvenTreeStockItemTestResult latestResult() {
    if (results.isEmpty) {
      return null;
    }

    return results.last;
  }

}


class InvenTreePart extends InvenTreeModel {

  @override
  String NAME = "Part";

  @override
  String URL = "part/";

  @override
  Map<String, String> defaultListFilters() {
    return {
      "cascade": "false",
      "active": "true",
    };
  }

  @override
  Map<String, String> defaultGetFilters() {
    return {
      "category_detail": "1",   // Include category detail information
    };
  }

  // Cached list of stock items
  List<InvenTreeStockItem> stockItems = List<InvenTreeStockItem>();

  int get stockItemCount => stockItems.length;

  // Request stock items for this part
  Future<void> getStockItems(BuildContext context, {bool showDialog=false}) async {

    await InvenTreeStockItem().list(
      context,
      filters: {
        "part": "${pk}",
        "in_stock": "true",
      },
    ).then((var items) {
      stockItems.clear();

      for (var item in items) {
        if (item is InvenTreeStockItem) {
          stockItems.add(item);
        }
      }
    });
  }

  int get supplier_count => jsondata['suppliers'] as int ?? 0;

  // Cached list of test templates
  List<InvenTreePartTestTemplate> testingTemplates = List<InvenTreePartTestTemplate>();

  int get testTemplateCount => testingTemplates.length;

  // Request test templates from the serve
  Future<void> getTestTemplates(BuildContext context, {bool showDialog=false}) async {

    InvenTreePartTestTemplate().list(
      context,
      filters: {
        "part": "${pk}",
      },
    ).then((var templates) {

      testingTemplates.clear();

      for (var t in templates) {
        if (t is InvenTreePartTestTemplate) {
          testingTemplates.add(t);
        }
      }
    });
  }

    // Get the number of stock on order for this Part
    double get onOrder => double.tryParse(jsondata['ordering'].toString() ?? '0');

    // Get the stock count for this Part
    double get inStock => double.tryParse(jsondata['in_stock'].toString() ?? '0');

    String get inStockString {

      if (inStock == inStock.toInt()) {
        return inStock.toInt().toString();
      } else {
        return inStock.toString();
      }
    }

    // Get the number of units being build for this Part
    double get building => double.tryParse(jsondata['building'].toString() ?? '0');

    // Get the number of BOM items in this Part (if it is an assembly)
    int get bomItemCount => jsondata['bom_items'] as int ?? 0;

    // Get the number of BOMs this Part is used in (if it is a component)
    int get usedInCount => jsondata['used_in'] as int ?? 0;

    bool get isAssembly => jsondata['assembly'] ?? false;

    bool get isComponent => jsondata['component'] ?? false;

    bool get isPurchaseable => jsondata['purchaseable'] ?? false;

    bool get isSalable => jsondata['salable'] ?? false;

    bool get isActive => jsondata['active'] ?? false;

    bool get isVirtual => jsondata['virtual'] ?? false;

    bool get isTrackable => jsondata['trackable'] ?? false;

    // Get the IPN (internal part number) for the Part instance
    String get IPN => jsondata['IPN'] as String ?? '';

    // Get the revision string for the Part instance
    String get revision => jsondata['revision'] as String ?? '';

    // Get the category ID for the Part instance (or 'null' if does not exist)
    int get categoryId => jsondata['category'] as int ?? null;

    // Get the category name for the Part instance
    String get categoryName {
      if (categoryId == null) return '';
      if (!jsondata.containsKey('category_detail')) return '';

      return jsondata['category_detail']['name'] as String ?? '';
    }

    // Get the category description for the Part instance
    String get categoryDescription {
      if (categoryId == null) return '';
      if (!jsondata.containsKey('category_detail')) return '';

      return jsondata['category_detail']['description'] as String ?? '';
    }
    // Get the image URL for the Part instance
    String get _image  => jsondata['image'] ?? '';

    // Get the thumbnail URL for the Part instance
    String get _thumbnail => jsondata['thumbnail'] ?? '';

    // Return the fully-qualified name for the Part instance
    String get fullname {

      String fn = jsondata['full_name'] ?? '';

      if (fn.isNotEmpty) return fn;

      List<String> elements = List<String>();

      if (IPN.isNotEmpty) elements.add(IPN);

      elements.add(name);

      if (revision.isNotEmpty) elements.add(revision);

      return elements.join(" | ");
    }

    // Return a path to the image for this Part
    String get image {
      // Use thumbnail as a backup
      String img = _image.isNotEmpty ? _image : _thumbnail;

      return img.isNotEmpty ? img : InvenTreeAPI.staticImage;
    }

    // Return a path to the thumbnail for this part
    String get thumbnail {
      // Use image as a backup
      String img = _thumbnail.isNotEmpty ? _thumbnail : _image;

      return img.isNotEmpty ? img : InvenTreeAPI.staticThumb;
    }

    // Return the "starred" status of this part
    bool get starred => jsondata['starred'] as bool ?? false;

    InvenTreePart() : super();

  InvenTreePart.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

    var part = InvenTreePart.fromJson(json);

    return part;
  }
}