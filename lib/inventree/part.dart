import 'package:InvenTree/api.dart';

import 'model.dart';
import 'dart:io';

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

  String get _image  => jsondata['image'] ?? '';

  String get _thumbnail => jsondata['thumbnail'] ?? '';

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