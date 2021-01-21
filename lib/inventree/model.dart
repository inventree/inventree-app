import 'dart:async';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String NAME = "Model";

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

  String get notes => jsondata['notes'] as String ?? '';

  int get parentId => jsondata['parent'] as int ?? -1;

  // Legacy API provided external link as "URL", while newer API uses "link"
  String get link => jsondata['link'] ?? jsondata['URL'] ?? '';

  void openLink() async {

    if (link.isNotEmpty) {
      print("Opening link: ${link}");

      if (await canLaunch(link)) {
        await launch(url);
      } else {
        // TODO
      }
    }
  }

  String get keywords => jsondata['keywords'] as String ?? '';

  // Create a new object from JSON data (not a constructor!)
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

      var obj = InvenTreeModel.fromJson(json);

      return obj;
  }

  // Return the API detail endpoint for this Model object
  String get url => "${URL}/${pk}/";

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

  Map<String, String> defaultListFilters() { return Map<String, String>(); }

  // A map of "default" headers to use when performing a GET request
  Map<String, String> defaultGetFilters() { return Map<String, String>(); }

  /*
   * Reload this object, by requesting data from the server
   */
  Future<bool> reload(BuildContext context) async {

    showProgressDialog(context, "Refreshing data", "Refreshing data for ${NAME}");

    var response = await api.get(url, params: defaultGetFilters())
      .timeout(Duration(seconds: 10))
      .catchError((e) {

          hideProgressDialog(context);

          if (e is TimeoutException) {
            showErrorDialog(context, "Timeout", "No response from server");
          } else {
            showErrorDialog(context, "Error", e.toString());
          }

          return null;
    });
    
    if (response == null) {
      return false;
    }
    
    hideProgressDialog(context);

    if (response.statusCode != 200) {
      print("Error retrieving data");
      return false;
    }

    final Map<String, dynamic> data = json.decode(response.body);

    jsondata = data;

    return true;
  }

  // POST data to update the model
  Future<bool> update(BuildContext context, {Map<String, String> values}) async {

    var addr = path.join(URL, pk.toString());

    if (!addr.endsWith("/")) {
      addr += "/";
    }

    showProgressDialog(context, "Updating ${NAME}", "Sending data to server");

    var response = await api.patch(addr, body: values)
        .timeout(Duration(seconds: 10))
        .catchError((e) {

          hideProgressDialog(context);

          if (e is TimeoutException) {
            showErrorDialog(context, "Timeout", "No response from server");
          } else {
            showErrorDialog(context, "Error", e.toString());
          }

          return null;
    });

    if (response == null) return false;

    hideProgressDialog(context);

    if (response.statusCode != 200) {
      print("Error updating ${NAME}: Status code ${response.statusCode}");
      return false;
    }

    return true;

  }

  // Return the detail view for the associated pk
  Future<InvenTreeModel> get(BuildContext context, int pk, {Map<String, String> filters}) async {

    // TODO - Add "timeout"
    // TODO - Add error catching

    var addr = path.join(URL, pk.toString());

    if (!addr.endsWith("/")) {
      addr += "/";
    }

    var params = defaultGetFilters();

    if (filters != null) {
      // Override any default values
      for (String key in filters.keys) {
        params[key] = filters[key];
      }
    }

    print("GET: $addr ${params.toString()}");

    showProgressDialog(context, "Requesting Data", "Requesting ${NAME} data from server");

    var response = await api.get(addr, params: params)
        .timeout(Duration(seconds: 10))
        .catchError((e) {

          hideProgressDialog(context);

          if (e is TimeoutException) {
            showErrorDialog(context, "Timeout", "No response from server");
          } else {
            showErrorDialog(context, "Error", e.toString());
          }
          return null;
      });

    if (response == null) {
      return null;
    }

    hideProgressDialog(context);

    if (response.statusCode != 200) {
      print("Error retrieving data");
      return null;
    }

    final data = json.decode(response.body);

    return createFromJson(data);
  }

  Future<InvenTreeModel> create(BuildContext context, Map<String, dynamic> data) async {

    print("CREATE: ${URL} ${data.toString()}");

    if (data.containsKey('pk')) {
      data.remove('pk');
    }

    if (data.containsKey('id')) {
      data.remove('id');
    }

    InvenTreeModel _model;

    await api.post(URL, body: data)
    .timeout(Duration(seconds: 5))
    .catchError((e) {
      print("Error creating new ${NAME}:");
      print(e.toString());
      return null;
    })
    .then((http.Response response) {
      // Server should return HTTP_201_CREATED
      if (response.statusCode == 201) {
        var decoded = json.decode(response.body);
        _model = createFromJson(decoded);
      } else {
        print("Error creating object: Status Code ${response.statusCode}");
        print(response.body);
      }
    });

    return _model;
  }

  // Return list of objects from the database, with optional filters
  Future<List<InvenTreeModel>> list(BuildContext context, {Map<String, String> filters, bool dialog=true}) async {

    if (filters == null) {
      filters = {};
    }

    var params = defaultListFilters();

    if (filters != null) {
      for (String key in filters.keys) {
        params[key] = filters[key];
      }
    }

    print("LIST: $URL ${params.toString()}");

    // TODO - Add "timeout"
    // TODO - Add error catching

    if (dialog) {
      showProgressDialog(context, "Requesting Data", "Requesting ${NAME} data from server");
    }

    var response = await api.get(URL, params:params)
      .timeout(Duration(seconds: 10))
      .catchError((e) {

        if (dialog) {
          hideProgressDialog(context);
        }

        if (e is TimeoutException) {
          if (dialog) {
            showErrorDialog(context, "Timeout", "No response from server");
          }
        } else {
          // Re-throw the error
          throw e;
        }

        return null;
    });

    if (response == null) {
      return null;
    }

    if (dialog) {
      hideProgressDialog(context);
    }

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
  bool matchAgainstString(String filter) {
    // Default implementation matches name and description
    // Override this behaviour in sub-class if required

    if (name.toLowerCase().contains(filter)) return true;
    if (description.toLowerCase().contains(filter)) return true;

    // No matches!
    return false;
  }

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


