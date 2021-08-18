import 'dart:async';
import 'dart:io';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/api.dart';
import 'package:flutter/cupertino.dart';
import 'package:inventree/inventree/sentry.dart';
import 'package:inventree/widget/dialogs.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:path/path.dart' as path;

import '../l10.dart';
import '../api_form.dart';

// Paginated response object
class InvenTreePageResponse {
  InvenTreePageResponse() {
    results = [];
  }

  void addResult(InvenTreeModel item) {
    results.add(item);
  }

  // Total number of results in the dataset
  int count = 0;

  int get length => results.length;

  List<InvenTreeModel> results = [];
}

/*
 * The InvenTreeModel class provides a base-level object
 * for interacting with InvenTree data.
 */
const int SOME_ID_PRIME = 5393;

class InvenTreeModel {
  @override
  bool operator ==(Object other) {
    return other is InvenTreeModel &&
        other.hashCode == this.hashCode;
  }

  @override
  int get hashCode => this.runtimeType.hashCode + (SOME_ID_PRIME * pk) + (SOME_ID_PRIME * SOME_ID_PRIME * name.hashCode);

  // Override the endpoint URL for each subclass
  String get URL => "";

  // Override the web URL for each subclass
  // Note: If the WEB_URL is the same (except for /api/) as URL then just leave blank
  String WEB_URL = "";

  String get webUrl {
    if (api.isConnected()) {
      String web = InvenTreeAPI().baseUrl;

      web += WEB_URL.isNotEmpty ? WEB_URL : URL;

      web += "/${pk}/";

      web = web.replaceAll("//", "/");

      return web;
    } else {
      return "";
    }
  }

  // Fields for editing / creating this model
  // Override per-model
  Map<String, dynamic> formFields() {
    return {};
  }

  Future<void> createForm(BuildContext context, String title,
      {String fileField = "",
      Map<String, dynamic> fields = const {},
      Map<String, dynamic> data = const {},
      Function(dynamic)? onSuccess}) async {
    if (fields.isEmpty) {
      fields = formFields();
    }

    launchApiForm(
      context,
      title,
      URL,
      fields,
      modelData: data,
      onSuccess: onSuccess,
      method: "POST",
      fileField: fileField,
    );
  }

  Future<void> editForm(BuildContext context, String title,
      {Map<String, dynamic> fields = const {},
      Function(dynamic)? onSuccess}) async {
    if (fields.isEmpty) {
      fields = formFields();
    }

    launchApiForm(context, title, url, fields,
        modelData: jsondata, onSuccess: onSuccess, method: "PATCH");
  }

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

  int get pk => (jsondata['pk'] ?? -1) as int;

  // Some common accessors
  String get name => jsondata['name'] ?? '';

  String get description => jsondata['description'] ?? '';

  String get notes => jsondata['notes'] ?? '';

  int get parentId => (jsondata['parent'] ?? -1) as int;

  // Legacy API provided external link as "URL", while newer API uses "link"
  String get link => jsondata['link'] ?? jsondata['URL'] ?? '';

  void goToInvenTreePage() async {
    if (await canLaunch(webUrl)) {
      await launch(webUrl);
    } else {
      // TODO
    }
  }

  void openLink() async {
    if (link.isNotEmpty) {
      if (await canLaunch(link)) {
        await launch(link);
      }
    }
  }

  String get keywords => jsondata['keywords'] ?? '';

  // Create a new object from JSON data (not a constructor!)
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

    var obj = InvenTreeModel.fromJson(json);

    return obj;
  }

  // Return the API detail endpoint for this Model object
  String get url => "${URL}/${pk}/".replaceAll("//", "/");

  // Search this Model type in the database
  Future<List<InvenTreeModel>> search(BuildContext context, String searchTerm,
      {Map<String, String> filters = const {}}) async {
    filters["search"] = searchTerm;

    final results = list(filters: filters);

    return results;
  }

  Map<String, String> defaultListFilters() {
    return Map<String, String>();
  }

  // A map of "default" headers to use when performing a GET request
  Map<String, String> defaultGetFilters() {
    return Map<String, String>();
  }

  /*
   * Reload this object, by requesting data from the server
   */
  Future<bool> reload() async {
    var response = await api.get(url,
        params: defaultGetFilters(), expectedStatusCode: 200);

    if (!response.isValid() ||
        response.data == null ||
        !(response.data is Map)) {
      // Report error
      if (response.statusCode > 0) {
        await sentryReportMessage(
            "InvenTreeModel.reload() returned invalid response",
            context: {
              "url": url,
              "statusCode": response.statusCode.toString(),
              "data": response.data?.toString() ?? "null",
              "valid": response.isValid().toString(),
              "error": response.error,
              "errorDetail": response.errorDetail,
            });
      }

      showServerError(
        L10().serverError,
        L10().errorFetch,
      );

      return false;
    }

    jsondata = response.data;

    return true;
  }

  // POST data to update the model
  Future<bool> update({Map<String, String> values = const {}}) async {
    var url = path.join(URL, pk.toString());

    if (!url.endsWith("/")) {
      url += "/";
    }

    var response = await api.patch(url, body: values, expectedStatusCode: 200);

    if (!response.isValid()) {
      return false;
    }

    return true;
  }

  // Return the detail view for the associated pk
  Future<InvenTreeModel?> get(int pk,
      {Map<String, String> filters = const {}}) async {
    // TODO - Add "timeout"
    // TODO - Add error catching

    var url = path.join(URL, pk.toString());

    if (!url.endsWith("/")) {
      url += "/";
    }

    var params = defaultGetFilters();

    // Override any default values
    for (String key in filters.keys) {
      params[key] = filters[key] ?? '';
    }

    var response = await api.get(url, params: params);

    if (!response.isValid() ||
        response.data == null ||
        !(response.data is Map)) {
      if (response.statusCode > 0) {
        await sentryReportMessage(
            "InvenTreeModel.get() returned invalid response",
            context: {
              "url": url,
              "statusCode": response.statusCode.toString(),
              "data": response.data?.toString() ?? "null",
              "valid": response.isValid().toString(),
              "error": response.error,
              "errorDetail": response.errorDetail,
            });
      }

      showServerError(
        L10().serverError,
        L10().errorFetch,
      );

      return null;
    }

    return createFromJson(response.data);
  }

  Future<InvenTreeModel?> create(Map<String, dynamic> data) async {
    print("CREATE: ${URL} ${data.toString()}");

    if (data.containsKey('pk')) {
      data.remove('pk');
    }

    if (data.containsKey('id')) {
      data.remove('id');
    }

    var response = await api.post(URL, body: data);

    // Invalid response returned from server
    if (!response.isValid() ||
        response.data == null ||
        !(response.data is Map)) {
      if (response.statusCode > 0) {
        await sentryReportMessage(
            "InvenTreeModel.create() returned invalid response",
            context: {
              "url": url,
              "statusCode": response.statusCode.toString(),
              "data": response.data?.toString() ?? "null",
              "valid": response.isValid().toString(),
              "error": response.error,
              "errorDetail": response.errorDetail,
            });
      }

      showServerError(
        L10().serverError,
        L10().errorCreate,
      );

      return null;
    }

    return createFromJson(response.data);
  }

  Future<InvenTreePageResponse?> listPaginated(int limit, int offset,
      {Map<String, String> filters = const {}}) async {
    var params = defaultListFilters();

    for (String key in filters.keys) {
      params[key] = filters[key] ?? '';
    }

    params["limit"] = "${limit}";
    params["offset"] = "${offset}";

    var response = await api.get(URL, params: params);

    if (!response.isValid()) {
      return null;
    }

    // Construct the response
    InvenTreePageResponse page = new InvenTreePageResponse();

    if (response.data.containsKey("count") &&
        response.data.containsKey("results")) {
      page.count = response.data["count"] as int;

      page.results = [];

      for (var result in response.data["results"]) {
        page.addResult(createFromJson(result));
      }

      return page;
    } else {
      return null;
    }
  }

  // Return list of objects from the database, with optional filters
  Future<List<InvenTreeModel>> list(
      {Map<String, String> filters = const {}}) async {
    var params = defaultListFilters();

    for (String key in filters.keys) {
      params[key] = filters[key] ?? '';
    }

    var response = await api.get(URL, params: params);

    // A list of "InvenTreeModel" items
    List<InvenTreeModel> results = [];

    if (!response.isValid()) {
      return results;
    }

    dynamic data;

    if (response.data is List) {
      data = response.data;
    } else if (response.data.containsKey('results')) {
      data = response.data['results'];
    } else {
      data = [];
    }

    for (var d in data) {
      // Create a new object (of the current class type
      InvenTreeModel obj = createFromJson(d);

      results.add(obj);
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

class InvenTreeAttachment extends InvenTreeModel {
  // Class representing an "attachment" file

  InvenTreeAttachment() : super();

  String get attachment => jsondata["attachment"] ?? '';

  // Return the filename of the attachment
  String get filename {
    return attachment.split("/").last;
  }

  IconData get icon {
    String fn = filename.toLowerCase();

    if (fn.endsWith(".pdf")) {
      return FontAwesomeIcons.filePdf;
    } else if (fn.endsWith(".csv")) {
      return FontAwesomeIcons.fileCsv;
    } else if (fn.endsWith(".doc") || fn.endsWith(".docx")) {
      return FontAwesomeIcons.fileWord;
    } else if (fn.endsWith(".xls") || fn.endsWith(".xlsx")) {
      return FontAwesomeIcons.fileExcel;
    }

    // Image formats
    final List<String> img_formats = [
      ".png",
      ".jpg",
      ".gif",
      ".bmp",
      ".svg",
    ];

    for (String fmt in img_formats) {
      if (fn.endsWith(fmt)) {
        return FontAwesomeIcons.fileImage;
      }
    }

    return FontAwesomeIcons.fileAlt;
  }

  String get comment => jsondata["comment"] ?? '';

  DateTime? get uploadDate {
    if (jsondata.containsKey("upload_date")) {
      return DateTime.tryParse(jsondata["upload_date"] ?? '');
    } else {
      return null;
    }
  }

  InvenTreeAttachment.fromJson(Map<String, dynamic> json)
      : super.fromJson(json);

  Future<bool> uploadAttachment(File attachment,
      {String comment = "", Map<String, String> fields = const {}}) async {
    final APIResponse response = await InvenTreeAPI().uploadFile(
        URL, attachment,
        method: 'POST', name: 'attachment', fields: fields);

    return response.successful();
  }

  Future<void> downloadAttachment() async {
    await InvenTreeAPI().downloadFile(attachment);
  }
}
