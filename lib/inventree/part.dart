import 'package:InvenTree/api.dart';

import 'model.dart';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class InvenTreePartCategory extends InvenTreeModel {
  @override
  String URL = "part/category/";

  String get pathstring => jsondata['pathstring'] ?? '';

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
  String URL = "part/";

  int get categoryId => jsondata['category'] as int ?? -1;

  String get categoryName => jsondata['category__name'] ?? '';

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