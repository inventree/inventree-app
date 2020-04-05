import 'package:InvenTree/api.dart';

import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;


/**
 * The InvenTreeModel class provides a base-level object
 * for interacting with InvenTree data.
 */
class InvenTreeModel {

  // Override the endpoint URL for each subclass
  String URL = "";

  // JSON data which defines this object
  Map<String, dynamic> jsondata = {};

  // Accessor for the API
  var api = InvenTreeAPI();

  // Default empty object constructor
  InvenTreeModel() {
    jsondata.clear();
  }

  // Construct an InvenTreeModel from a JSON data object
  InvenTreeModel.fromJson(Map<String, dynamic> json) {

    // Store the json object
    jsondata = json;

  }

  int get pk => jsondata['pk'] ?? -1;

  // Some common accessors
  String get name => jsondata['name'] ?? '';

  String get description => jsondata['description'] ?? '';

  int get parentId => jsondata['parent'] ?? -1;

  String get link => jsondata['URL'] ?? '';

  // Create a new object from JSON data (not a constructor!)
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

      var obj = InvenTreeModel.fromJson(json);

      return obj;
  }

  String get url{ return path.join(URL, pk.toString()); }

  /*
  // Search this Model type in the database
  Future<List<InvenTreeModel>> search(String searchTerm) async {

    String addr = url + "?search=" + search;

    print("Searching endpoint: $url");

    // TODO - Add "timeout"
    // TODO - Add error catching

    var response =

  }
  */

  // Return the detail view for the associated pk
  Future<InvenTreeModel> get(int pk) async {

    // TODO - Add "timeout"
    // TODO - Add error catching

    var addr = path.join(URL, pk.toString());

    if (!addr.endsWith("/")) {
      addr += "/";
    }

    var response = await InvenTreeAPI().get(addr);

    if (response.statusCode != 200) {
      print("Error retrieving data");
      return null;
    }

    final data = json.decode(response.body);

    return createFromJson(data);
  }

  // Return list of objects from the database, with optional filters
  Future<List<InvenTreeModel>> list({Map<String, String> filters}) async {

    if (filters == null) {
      filters = {};
    }

    print("Listing endpoint: $URL");

    // TODO - Add "timeout"
    // TODO - Add error catching

    var response = await InvenTreeAPI().get(URL, params:filters);

    // A list of "InvenTreeModel" items
    List<InvenTreeModel> results = new List<InvenTreeModel>();

    if (response.statusCode != 200) {
      print("Error retreiving data");
      return results;
    }

    final data = json.decode(response.body);

    // TODO - handle possible error cases:
    // - No data receieved
    // - Data is not a list of maps

    for (var d in data) {

      // Create a new object (of the current class type
      InvenTreeModel obj = createFromJson(d);

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

  // Override this function for each sub-class
  bool matchAgainstString(String filter) => false;

  // Filter this item against a list of provided filters
  // Each filter must be matched
  // Used for (e.g.) filtering returned results
  bool filter(String filterString) {

    List<String> filters = filterString.trim().toLowerCase().split(" ");

    for (var f in filters) {
      if (!matchAgainstString(f)) {
        return false;
      }
    }

    return true;
  }


}


