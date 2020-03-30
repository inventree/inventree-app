import 'api.dart';

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
  String _name = "InvenTree";

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

  int get pk {
    return _data['pk'] ?? -1;
  }

  // Create a new object from JSON data (not a constructor!)
  InvenTreeObject _createFromJson(Map<String, dynamic> json) {
      print("creating new object");

      var obj = InvenTreeObject.fromJson(json);

      return obj;
  }

  String get url{ return path.join(_URL, pk.toString()); }

  // Return list of objects from the database, with optional filters
  Future<http.Response> list({Map<String, String> filters}) async {

    if (filters == null) {
      filters = {};
    }

    print("Listing endpoint: " + _URL);

    // TODO - Add "timeout"
    // TODO - Add error catching

    InvenTreeAPI().get(_URL, params:filters).then((http.Response response) {

     final data = json.decode(response.body);

     for (var d in data) {
       print(d);

       var obj = _createFromJson(d);

       if (obj is InvenTreePart) {
         print("Part -> " + obj.name + obj.description);
       } else {
         print("Not part :'(");
         print(obj.runtimeType);
       }
     }

     // var obj = _createFromJson(data);

    });
  }


  // Provide a listing of objects at the endpoint
  // TODO - Static function which returns a list of objects (of this class)

  // TODO - Define a 'delete' function

  // TODO - Define a 'save' / 'update' function


}


class InvenTreePart extends InvenTreeObject {

  @override
  String _URL = "part/";

  @override
  String _name = "part";

  String get name {
    return _data['name'] ?? '';
  }

  String get description {
    return _data['description'] ?? '';
  }

  int get categoryId {
    return _data['category'] as int ?? -1;
  }

  String get categoryName {
    return _data['category__name'] ?? '';
  }

  InvenTreePart() : super();

  InvenTreePart.fromJson(Map<String, dynamic> json) : super.fromJson(json) {

  }

  @override
  InvenTreeObject _createFromJson(Map<String, dynamic> json) {

    var part = InvenTreePart.fromJson(json);

    print("creating new part!");
    print(json);

    return part;

  }

  // TODO - Is there a way of making this "list" function generic to the InvenTreeObject class?
  // In an ideal world it would return a list of
  //List<InvenTreePart> list()
}