import 'dart:convert';

import 'package:InvenTree/api.dart';

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


class InvenTreePart extends InvenTreeModel {

  @override
  String NAME = "Part";

  @override
  String URL = "part/";

  // Get the number of stock on order for this Part
  double get onOrder => double.tryParse(jsondata['ordering'].toString() ?? '0');

  // Get the stock count for this Part
  double get inStock => double.tryParse(jsondata['in_stock'].toString() ?? '0');

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

  // Get the IPN (internal part number) for the Part instance
  String get IPN => jsondata['IPN'] as String ?? '';

  // Get the revision string for the Part instance
  String get revision => jsondata['revision'] as String ?? '';

  // Get the category ID for the Part instance (or 'null' if does not exist)
  int get categoryId => jsondata['category'] as int ?? null;

  // Get the category name for the Part instance
  String get categoryName => jsondata['category_name'] ?? '';

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