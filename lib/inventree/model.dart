import "dart:async";
import "dart:io";

import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/api.dart";
import "package:flutter/cupertino.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/widget/dialogs.dart";
import "package:url_launcher/url_launcher.dart";

import "package:path/path.dart" as path;

import "package:inventree/l10.dart";
import "package:inventree/api_form.dart";


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
class InvenTreeModel {

  InvenTreeModel();

  // Construct an InvenTreeModel from a JSON data object
  InvenTreeModel.fromJson(this.jsondata);

  // Override the endpoint URL for each subclass
  String get URL => "";

  // Override the web URL for each subclass
  // Note: If the WEB_URL is the same (except for /api/) as URL then just leave blank
  String get WEB_URL => "";

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

  Future<void> createForm(BuildContext context, String title, {String fileField = "", Map<String, dynamic> fields=const{}, Map<String, dynamic> data=const {}, Function(dynamic)? onSuccess}) async {

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

  Future<void> editForm(BuildContext context, String title, {Map<String, dynamic> fields=const {}, Function(dynamic)? onSuccess}) async {

    if (fields.isEmpty) {
      fields = formFields();
    }

    launchApiForm(
      context,
      title,
      url,
      fields,
      modelData: jsondata,
      onSuccess: onSuccess,
      method: "PATCH"
    );

  }

  // JSON data which defines this object
  Map<String, dynamic> jsondata = {};

  // Accessor for the API
  InvenTreeAPI get api => InvenTreeAPI();

  int get pk => (jsondata["pk"] ?? -1) as int;

  // Some common accessors
  String get name => (jsondata["name"] ?? "") as String;

  String get description => (jsondata["description"] ?? "") as String;

  String get notes => (jsondata["notes"] ?? "") as String;

  int get parentId => (jsondata["parent"] ?? -1) as int;

  // Legacy API provided external link as "URL", while newer API uses "link"
  String get link => (jsondata["link"] ?? jsondata["URL"] ?? "") as String;

  Future <void> goToInvenTreePage() async {

    if (await canLaunch(webUrl)) {
      await launch(webUrl);
    } else {
      // TODO
    }
  }

  Future <void> openLink() async {

    if (link.isNotEmpty) {

      if (await canLaunch(link)) {
        await launch(link);
      }
    }
  }

  String get keywords => (jsondata["keywords"] ?? "") as String;

  // Create a new object from JSON data (not a constructor!)
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

      var obj = InvenTreeModel.fromJson(json);

      return obj;
  }

  // Return the API detail endpoint for this Model object
  String get url => "${URL}/${pk}/".replaceAll("//", "/");

  // Search this Model type in the database
  Future<List<InvenTreeModel>> search(String searchTerm, {Map<String, String> filters = const {}, int offset = 0, int limit = 25}) async {

    Map<String, String> searchFilters = {};

    for (String key in filters.keys) {
      searchFilters[key] = filters[key] ?? "";
    }

    searchFilters["search"] = searchTerm;
    searchFilters["offset"] = "${offset}";
    searchFilters["limit"] = "${limit}";

    final results = list(filters: searchFilters);

    return results;

  }

  Map<String, String> defaultListFilters() {
    return {};
  }

  // A map of "default" headers to use when performing a GET request
  Map<String, String> defaultGetFilters() {
    return {};
  }

  /*
   * Reload this object, by requesting data from the server
   */
  Future<bool> reload() async {

    var response = await api.get(url, params: defaultGetFilters(), expectedStatusCode: 200);

    if (!response.isValid() || response.data == null || (response.data is! Map)) {

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
            }
        );
      }

      showServerError(
        L10().serverError,
        L10().errorFetch,
      );

      return false;

    }

    jsondata = response.asMap();

    return true;
  }

  // POST data to update the model
  Future<bool> update({Map<String, String> values = const {}}) async {

    var url = path.join(URL, pk.toString());

    if (!url.endsWith("/")) {
      url += "/";
    }

    var response = await api.patch(
      url,
      body: values,
      expectedStatusCode: 200
    );

    if (!response.isValid()) {
      return false;
    }

    return true;
  }

  // Return the detail view for the associated pk
  Future<InvenTreeModel?> get(int pk, {Map<String, String> filters = const {}}) async {

    // TODO - Add "timeout"
    // TODO - Add error catching

    var url = path.join(URL, pk.toString());

    if (!url.endsWith("/")) {
      url += "/";
    }

    var params = defaultGetFilters();

    // Override any default values
    for (String key in filters.keys) {
      params[key] = filters[key] ?? "";
    }

    var response = await api.get(url, params: params);

    if (!response.isValid() || response.data == null || response.data is! Map) {

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
            }
        );
      }

      showServerError(
        L10().serverError,
        L10().errorFetch,
      );

      return null;

    }

    return createFromJson(response.asMap());
  }

  Future<InvenTreeModel?> create(Map<String, dynamic> data) async {

    if (data.containsKey("pk")) {
      data.remove("pk");
    }

    if (data.containsKey("id")) {
      data.remove("id");
    }

    var response = await api.post(URL, body: data);

    // Invalid response returned from server
    if (!response.isValid() || response.data == null || response.data is! Map) {

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
            }
        );
      }

      showServerError(
        L10().serverError,
        L10().errorCreate,
      );


      return null;
    }

    return createFromJson(response.asMap());
  }

  Future<InvenTreePageResponse?> listPaginated(int limit, int offset, {Map<String, String> filters = const {}}) async {
    var params = defaultListFilters();

    for (String key in filters.keys) {
      params[key] = filters[key] ?? "";
    }

    params["limit"] = "${limit}";
    params["offset"] = "${offset}";

    var response = await api.get(URL, params: params);

    if (!response.isValid()) {
      return null;
    }

    // Construct the response
    InvenTreePageResponse page = InvenTreePageResponse();

    var data = response.asMap();

    if (data.containsKey("count") && data.containsKey("results")) {
       page.count = (data["count"] ?? 0) as int;

       page.results = [];

       for (var result in response.data["results"]) {
         page.addResult(createFromJson(result as Map<String, dynamic>));
       }

       return page;

    } else {
      return null;
    }
  }

  // Return list of objects from the database, with optional filters
  Future<List<InvenTreeModel>> list({Map<String, String> filters = const {}}) async {

    var params = defaultListFilters();

    for (String key in filters.keys) {
      params[key] = filters[key] ?? "";
    }

    var response = await api.get(URL, params: params);

    // A list of "InvenTreeModel" items
    List<InvenTreeModel> results = [];

    if (!response.isValid()) {
      return results;
    }

    List<dynamic> data = [];

    if (response.isList()) {
      data = response.asList();
    } else if (response.isMap()) {
      var mData = response.asMap();

      if (mData.containsKey("results")) {
        data = (response.data["results"] ?? []) as List<dynamic>;
      }
    }

    for (var d in data) {

      // Create a new object (of the current class type
      InvenTreeModel obj = createFromJson(d as Map<String, dynamic>);

      results.add(obj);
    }

    return results;
  }


  // Provide a listing of objects at the endpoint
  // TODO - Static function which returns a list of objects (of this class)

  // TODO - Define a "delete" function

  // TODO - Define a "save" / "update" function

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

  InvenTreeAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  String get attachment => (jsondata["attachment"] ?? "") as String;

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

  String get comment => (jsondata["comment"] ?? "") as String;

  DateTime? get uploadDate {
    if (jsondata.containsKey("upload_date")) {
      return DateTime.tryParse((jsondata["upload_date"] ?? "") as String);
    } else {
      return null;
    }
  }

  Future<bool> uploadAttachment(File attachment, {String comment = "", Map<String, String> fields = const {}}) async {

    final APIResponse response = await InvenTreeAPI().uploadFile(
        URL,
        attachment,
        method: "POST",
        name: "attachment",
        fields: fields
    );

    return response.successful();
  }

  Future<void> downloadAttachment() async {

    await InvenTreeAPI().downloadFile(attachment);

  }

}


