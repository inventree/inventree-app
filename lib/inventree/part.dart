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

  // Return a fully-qualified path to the image for this Part
  String get image {
    String img = _image.isNotEmpty ? _image : _thumbnail;

    if (img.isEmpty) {
      return InvenTreeAPI().makeUrl('/static/img/blank_image.png');
    } else {
      return InvenTreeAPI().makeUrl(img);
    }
  }

  String get thumbnail {
    String img = _thumbnail.isNotEmpty ? _thumbnail : _image;

    if (img.isEmpty) {
      return InvenTreeAPI().makeUrl('/static/img/blank_image.thumbnail.png');
    } else {
      return InvenTreeAPI().makeUrl(img);
    }
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