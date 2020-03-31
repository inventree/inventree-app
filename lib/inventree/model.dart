import 'package:InvenTree/api.dart';

import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;


/**
 * The InvenTreeObject class provides a base-level object
 * for interacting with InvenTree data.
 */
class InvenTreeObject {

  // Override the endpoint URL for each subclass
  String _URL = "";

  // JSON data which defines this object
  Map<String, dynamic> _data = {};

  // Accessor for the API
  var api = InvenTreeAPI();

  // Default empty object constructor
  InvenTreeObject() {
    _data.clear();
  }

  // Construct an InvenTreeObject from a JSON data object
  InvenTreeObject.fromJson(Map<String, dynamic> json) {

    // Store the json object
    _data = json;

  }

  int get pk => _data['pk'] ?? -1;

  // Some common accessors
  String get name => _data['name'] ?? '';

  String get description => _data['description'] ?? '';

  int get parentId => _data['parent'] ?? -1;

  // Create a new object from JSON data (not a constructor!)
  InvenTreeObject _createFromJson(Map<String, dynamic> json) {
      print("creating new object");

      var obj = InvenTreeObject.fromJson(json);

      return obj;
  }

  String get url{ return path.join(_URL, pk.toString()); }

  // Return list of objects from the database, with optional filters
  Future<List<InvenTreeObject>> list({Map<String, String> filters}) async {

    if (filters == null) {
      filters = {};
    }

    print("Listing endpoint: " + _URL);

    // TODO - Add "timeout"
    // TODO - Add error catching

    var response = await InvenTreeAPI().get(_URL, params:filters);

    // A list of "InvenTreeObject" items
    List<InvenTreeObject> results = new List<InvenTreeObject>();

    if (response.statusCode != 200) {
      print("Error retreiving data");
      return results;
    }

    final data = json.decode(response.body);

    for (var d in data) {

      // Create a new object (of the current class type
      InvenTreeObject obj = _createFromJson(d);

      if (obj != null) {
        results.add(obj);
      }
    }

    return results;
  }


  // Provide a listing of objects at the endpoint
  // TODO - Static function which returns a list of objects (of this class)

  // TODO - Define a 'delete' function

  // TODO - Define a 'save' / 'update' function


}


class InvenTreePartCategory extends InvenTreeObject {
  @override
  String _URL = "part/category/";

  String get pathstring => _data['pathstring'] ?? '';

  InvenTreePartCategory() : super();

  InvenTreePartCategory.fromJson(Map<String, dynamic> json) : super.fromJson(json) {

  }

  @override
  InvenTreeObject _createFromJson(Map<String, dynamic> json) {
    var cat = InvenTreePartCategory.fromJson(json);

    // TODO ?

    return cat;
  }
}


class InvenTreePart extends InvenTreeObject {

  @override
  String _URL = "part/";

  int get categoryId => _data['category'] as int ?? -1;

  String get categoryName => _data['category__name'] ?? '';

  InvenTreePart() : super();

  InvenTreePart.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  @override
  InvenTreeObject _createFromJson(Map<String, dynamic> json) {

    var part = InvenTreePart.fromJson(json);

    return part;

  }
}