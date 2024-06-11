import "dart:async";
import "dart:io";

import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:flutter/material.dart";
import "package:inventree/widget/snacks.dart";
import "package:url_launcher/url_launcher.dart";
import "package:path/path.dart" as path;

import "package:inventree/api.dart";
import "package:inventree/api_form.dart";
import "package:inventree/fa_icon_mapping.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/widget/dialogs.dart";


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

  // Update whenever the model is loaded from the server
  DateTime? lastReload;

  bool reloadedWithin(Duration d) {
    if (lastReload == null) {
      return false;
    } else {
      return lastReload!.add(d).isAfter(DateTime.now());
    }
  }

  // Override the endpoint URL for each subclass
  String get URL => "";

  // Override the web URL for each subclass
  // Note: If the WEB_URL is the same (except for /api/) as URL then just leave blank
  String get WEB_URL => "";

  // Return the "model type" of this model
  String get MODEL_TYPE => "";

  // Helper function to set a value in the JSON data
  void setValue(String key, dynamic value) {
    jsondata[key] = value;
  }

  // return a dynamic value from the JSON data
  // optionally we can specifiy a "subKey" to get a value from a sub-dictionary
  dynamic getValue(String key, {dynamic backup, String subKey = ""}) {
    Map<String, dynamic> data = jsondata;

    // If a subKey is specified, we need to dig deeper into the JSON data
    if (subKey.isNotEmpty) {

      if (!data.containsKey(subKey)) {
        debug("JSON data does not contain subKey '$subKey' for key '$key'");
        return backup;
      }

      dynamic sub_data = data[subKey];

      if (sub_data is Map<String, dynamic>) {
        data = (data[subKey] ?? {}) as Map<String, dynamic>;
      }

    }

    if (data.containsKey(key)) {
      return data[key];
    } else {
      debug("JSON data does not contain key '$key' (subKey '${subKey}')");
      return backup;
    }
  }

  // Helper function to get sub-map from JSON data
  Map<String, dynamic> getMap(String key, {Map<String, dynamic> backup = const {}, String subKey = ""}) {
    dynamic value = getValue(key, backup: backup, subKey: subKey);

    if (value == null) {
      return backup;
    }

    return value as Map<String, dynamic>;
  }

  // Helper function to get string value from JSON data
  String getString(String key, {String backup = "", String subKey = ""}) {
    dynamic value = getValue(key, backup: backup, subKey: subKey);

    if (value == null) {
      return backup;
    }

    return value.toString();
  }

  // Helper function to get integer value from JSON data
  int getInt(String key, {int backup = -1, String subKey = ""}) {
    dynamic value = getValue(key, backup: backup, subKey: subKey);

    if (value == null) {
      return backup;
    }

    return int.tryParse(value.toString()) ?? backup;
  }

  // Helper function to get double value from JSON data
  double getDouble(String key, {double backup = 0.0, String subKey = ""}) {
    dynamic value = getValue(key, backup: backup, subKey: subKey);

    if (value == null) {
      return backup;
    }

    return double.tryParse(value.toString()) ?? backup;
  }

  // Helper function to get boolean value from json data
  bool getBool(String key, {bool backup = false, String subKey = ""}) {
    dynamic value = getValue(key, backup: backup, subKey: subKey);

    if (value == null) {
      return backup;
    }

    return value.toString().toLowerCase() == "true";
  }

  // Return the InvenTree web server URL for this object
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

  /* Return a list of roles which may be required for this model
   * If multiple roles are required, *any* role which passes the check is sufficient
   */
  List<String> get rolesRequired {
    // Default implementation should not be called
    debug("rolesRequired() not implemented for model ${URL} - returning empty list");
    return [];
  }

  // Test if the user can "edit" this model
  bool get canEdit {
    for (String role in rolesRequired) {
      if (InvenTreeAPI().checkPermission(role, "change")) {
        return true;
      }
    }

    // Fallback
    return false;
  }

  // Test if the user can "create" this model
  bool get canCreate {
    for (String role in rolesRequired) {
      if (InvenTreeAPI().checkPermission(role, "add")) {
        return true;
      }
    }

    // Fallback
    return false;
  }

  // Test if the user can "delete" this model
  bool get canDelete {
    for (String role in rolesRequired) {
      if (InvenTreeAPI().checkPermission(role, "delete")) {
        return true;
      }
    }

    // Fallback
    return false;
  }

  // Test if the user can "view" this model
  bool get canView {
    for (String role in rolesRequired) {
      if (InvenTreeAPI().checkPermission(role, "view")) {
        return true;
      }
    }

    // Fallback
    return false;
  }

  // Fields for editing / creating this model
  // Override per-model
  Map<String, Map<String, dynamic>> formFields() {

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

  /*
   * Launch a modal form to edit the fields available to this model instance.
   */
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

  int get pk => getInt("pk");
  
  // Some common accessors
  String get name => getString("name");

  String get description => getString("description");
  
  String get notes => getString("notes");

  int get parentId => getInt("parent");

  // Legacy API provided external link as "URL", while newer API uses "link"
  String get link => (jsondata["link"] ?? jsondata["URL"] ?? "") as String;

  /*
   * Attempt to extract a custom icon for this model.
   * If icon data is provided, attempt to convert to a FontAwesome icon
   *
   * Icon data *should* be presented something like "fas fa-boxes" / "fab fa-github" (etc):
   *
   * - First part specifies the *style*
   * - Second part specifies the icon
   *
   */
  FaIcon? get customIcon {
    String icon = (jsondata["icon"] ?? "").toString();

    // Empty icon (default)
    if (icon.isEmpty) {
      return null;
    }

    final split = icon.trim().split(" ");

    // Must have two distinct units
    if (split.length != 2) {
      return null;
    }

    String style = split[0];
    String name = split[1];

    // Remove "fa-" leading text (if provided)
    if (name.startsWith("fa-")) {
      name = name.substring(3);
    }

    int iconHex = fontAwesomeIconMap[name] ?? 0;

    // No match for the icon name
    if (iconHex == 0) {
      return null;
    }

    switch (style) {
      case "fas":
        return FaIcon(IconDataSolid(iconHex));
      case "fab":
        return FaIcon(IconDataBrands(iconHex));
      case "fa":
        return FaIcon(IconDataRegular(iconHex));
      case "fal":
        return FaIcon(IconDataLight(iconHex));
      default:
        // No match
        return null;
    }
  }

  /* Extract any custom barcode data available for the model.
   * Note that old API used 'uid' (only for StockItem),
   * but this was updated to use 'barcode_hash'
   */
  String get customBarcode {
    if (jsondata.containsKey("uid")) {
      return jsondata["uid"] as String;
    } else if (jsondata.containsKey("barcode_hash")) {
      return jsondata["barcode_hash"] as String;
    } else if (jsondata.containsKey("barcode")) {
      return jsondata["barcode"] as String;
    }

    // Empty string if no match
    return "";
  }

  Future <void> goToInvenTreePage() async {

    var uri = Uri.tryParse(webUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // TODO
    }
  }

  Future <void> openLink() async {

    if (link.isNotEmpty) {
      var uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  String get keywords => getString("keywords");
  
  // Create a new object from JSON data (not a constructor!)
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeModel.fromJson(json);

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

  // Return the number of results that would meet a particular "query"
  Future<int> count({Map<String, String> filters = const {}, String searchQuery = ""} ) async {

    var params = defaultListFilters();

    filters.forEach((String key, String value) {
      params[key] = value;
    });

    if (searchQuery.isNotEmpty) {
      params["search"] = searchQuery;
    }

    // Limit to 1 result, for quick DB access
    params["limit"] = "1";

    var response = await api.get(URL, params: params);

    if (response.isValid()) {
      int n = int.tryParse(response.data["count"].toString()) ?? 0;
      return n;
    } else {
      return 0;
    }
}

  Map<String, String> defaultListFilters() {
    return {};
  }

  // A map of "default" headers to use when performing a GET request
  Map<String, String> defaultGetFilters() {
    return {};
  }

  /*
   * Report error information to sentry, when a model operation fails.
   */
  Future<void> reportModelError(String title, APIResponse response, {Map<String, String> context = const {}}) async {

    String dataString = response.data?.toString() ?? "null";

    // If the response has "errorDetail" set, then the error has already been handled, and there is no need to continue
    if (response.errorDetail.isNotEmpty) {
      return;
    }

    // If the response status code indicates a server error, then this has already been reported
    if (response.statusCode >= 500) {
      return;
    }

    if (dataString.length > 500) {
      dataString = dataString.substring(0, 500);
    }

    // Add some default context data

    context["url"] = response.url.toString();
    context["statusCode"] = response.statusCode.toString();
    context["responseData"] = dataString;
    context["valid"] = response.isValid().toString();
    context["error"] = response.error;
    context["errorDetail"] = response.errorDetail;
    context["isNull"] = response.data == null ? "true" : "false";
    context["dataType"] = response.data?.runtimeType.toString() ?? "null";
    context["model"] = URL;

    await sentryReportMessage(
      title,
      context: context,
    );
  }

  /// Delete the instance on the remote server
  /// Returns true if the operation was successful, else false
  Future<bool> delete() async {

    // Return if we do not have a valid pk
    if (pk < 0) {
      return false;
    }

    var response = await api.delete(url);

    if (!response.isValid() || response.data == null || (response.data is! Map)) {

      reportModelError(
        "InvenTreeModel.delete() returned invalid response",
        response,
      );

      showServerError(
        url,
        L10().serverError,
        L10().errorDelete,
      );

      return false;
    }

    // Status code should be 204 for "record deleted"
    return response.statusCode == 204;
  }

  /*
   * Reload this object, by requesting data from the server
   */
  Future<bool> reload() async {

    // If we do not have a valid pk (for some reason), exit immediately
    if (pk < 0) {
      return false;
    }

    var response = await api.get(url, params: defaultGetFilters(), expectedStatusCode: 200);

    // A valid response has been returned
    if (response.isValid() && response.statusCode == 200) {

      // Returned data was not a valid JSON object
      if (response.data == null || response.data is! Map) {
        reportModelError(
            "InvenTreeModel.reload() returned invalid response",
            response,
            context: {
              "pk": pk.toString(),
            }
        );

        showServerError(
          url,
          L10().serverError,
          L10().responseInvalid,
        );

        return false;
      }
    } else {

      switch (response.statusCode) {
        case 404: // Object has been deleted
          showSnackIcon(
            L10().itemDeleted,
            success: false,
          );
          break;
        default:
          String detail = L10().errorFetch;
          detail += "\n${L10().statusCode}: ${response.statusCode}";

          showServerError(
              url,
              L10().serverError,
              detail
          );
          break;
      }

      return false;
    }

    lastReload = DateTime.now();

    jsondata = response.asMap();

    return true;
  }

  // POST data to update the model
  Future<APIResponse> update({Map<String, String> values = const {}, int? expectedStatusCode = 200}) async {

    var url = path.join(URL, pk.toString());

    // Return if we do not have a valid pk
    if (pk < 0) {
      return APIResponse(
        url: url,
      );
    }

    if (!url.endsWith("/")) {
      url += "/";
    }

    final response = await api.patch(
      url,
      body: values,
      expectedStatusCode: expectedStatusCode,
    );

    return response;
  }

  // Return the detail view for the associated pk
  Future<InvenTreeModel?> getModel(String pk, {Map<String, String> filters = const {}}) async {

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

      if (response.statusCode != -1) {
        // Report error
        reportModelError(
            "InvenTreeModel.getModel() returned invalid response",
            response,
            context: {
              "filters": filters.toString(),
              "pk": pk,
            }
        );
      }

      showServerError(
        url,
        L10().serverError,
        L10().errorFetch,
      );

      return null;

    }

    lastReload = DateTime.now();

    return createFromJson(response.asMap());
  }

  Future<InvenTreeModel?> get(int pk, {Map<String, String> filters = const {}}) async {

    if (pk < 0) {
      return null;
    }

    return getModel(pk.toString(), filters: filters);
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

      reportModelError(
          "InvenTreeModel.create() returned invalid response",
          response,
          context: {
            "pk": pk.toString(),
          }
      );

      showServerError(
        URL,
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

    /* Special case: "original_search":
     * - We may wish to provide an original "query" which is augmented by the user
     * - Thus, "search" and "original_search" may both be provided
     * - In such a case, we want to concatenate them together
     */
    if (params.containsKey("original_search")) {

      String search = params["search"] ?? "";
      String original = params["original_search"] ?? "";

      params["search"] = "${search} ${original}".trim();

      params.remove("original_search");
    }

    var response = await api.get(URL, params: params);

    if (!response.isValid()) {
      return null;
    }

    // Construct the response
    InvenTreePageResponse page = InvenTreePageResponse();

    var dataMap = response.asMap();

    // First attempt is to look for paginated data, returned as a map

    if (dataMap.isNotEmpty && dataMap.containsKey("count") && dataMap.containsKey("results")) {
      page.count = (dataMap["count"] ?? 0) as int;

       page.results = [];

       List<dynamic> results = dataMap["results"] as List<dynamic>;

       for (dynamic result in results) {
         page.addResult(createFromJson(result as Map<String, dynamic>));
       }

       return page;
    }

    // Second attempt is to look for a list of data (not paginated)
    var dataList = response.asList();

    if (dataList.isNotEmpty) {
      page.count = dataList.length;
      page.results = [];

      for (var result in dataList) {
        page.addResult(createFromJson(result as Map<String, dynamic>));
    }

      return page;
    }

    // Finally, no results available
    return null;
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


/*
 * Class representing a single plugin instance
 */
class InvenTreePlugin extends InvenTreeModel {

  InvenTreePlugin() : super();

  InvenTreePlugin.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePlugin.fromJson(json);

  @override
  String get URL {

    /* Note: The plugin API endpoint changed at API version 90,
     * <  90 = 'plugin'
     * >= 90 = 'plugins'
     * Ref: https://github.com/inventree/InvenTree/pull/4186
     */
    if (api.isConnected() && api.apiVersion < 90) {
      return "plugin/";
    } else {
      return "plugins/";
    }
  }

  String get key => getString("key");
  
  bool get active => getBool("active");
  
  // Return the metadata struct for this plugin
  Map<String, dynamic> get _meta => (jsondata["meta"] ?? {}) as Map<String, dynamic>;

  String get humanName => (_meta["human_name"] ?? "") as String;

  // Return the mixins struct for this plugin
  Map<String, dynamic> get _mixins => (jsondata["mixins"] ?? {}) as Map<String, dynamic>;

  bool supportsMixin(String mixin) {
    return _mixins.containsKey(mixin);
  }
}


/*
 * Class representing a 'setting' object on the InvenTree server.
 * There are two sorts of settings available from the server, via the API:
 * - GlobalSetting (applicable to all users)
 * - UserSetting (applicable only to the current user)
 */
class InvenTreeGlobalSetting extends InvenTreeModel {

  InvenTreeGlobalSetting() : super();

  InvenTreeGlobalSetting.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeGlobalSetting createFromJson(Map<String, dynamic> json) {
    return InvenTreeGlobalSetting.fromJson(json);
  }

  @override
  String get URL => "settings/global/";

  String get key => getString("key");
  
  String get value => getString("value");
  
  String get type => getString("type");

}

class InvenTreeUserSetting extends InvenTreeGlobalSetting {

  InvenTreeUserSetting() : super();

  InvenTreeUserSetting.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeGlobalSetting createFromJson(Map<String, dynamic> json) {
    return InvenTreeGlobalSetting.fromJson(json);
  }

  @override
  String get URL => "settings/user/";
}


class InvenTreeAttachment extends InvenTreeModel {
  // Class representing an "attachment" file
  InvenTreeAttachment() : super();

  InvenTreeAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "attachment/";

  // Override this reference field for any subclasses
  // Note: This is used for the *legacy* attachment API
  String get REFERENCE_FIELD => "";

  // Override this reference field for any subclasses
  // Note: This is used for the *modern* attachment API
  String get REF_MODEL_TYPE => "";

  String get attachment => getString("attachment");
  
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

    return FontAwesomeIcons.fileLines;
  }

  String get comment => getString("comment");
  
  DateTime? get uploadDate {
    if (jsondata.containsKey("upload_date")) {
      return DateTime.tryParse((jsondata["upload_date"] ?? "") as String);
    } else {
      return null;
    }
  }

  // Return a count of how many attachments exist against the specified model ID
  Future<int> countAttachments(int modelId) {

    Map<String, String> filters = {};

    if (InvenTreeAPI().supportsModernAttachments) {
      filters["model_type"] = REF_MODEL_TYPE;
      filters["model_id"] = modelId.toString();
    } else {
      filters[REFERENCE_FIELD] = modelId.toString();
    }

    return count(filters: filters);
  }

  Future<bool> uploadAttachment(File attachment, String modelType, int modelId, {String comment = "", Map<String, String> fields = const {}}) async {

    // Ensure that the correct reference field is set
    Map<String, String> data = Map<String, String>.from(fields);

    String url = URL;

    if (InvenTreeAPI().supportsModernAttachments) {
      // All attachments are stored in a consolidated table
      url = "attachment/";
      data["model_id"] = modelId.toString();
      data["model_type"] = modelType;
    } else {
      data[REFERENCE_FIELD] = modelId.toString();
    }

    final APIResponse response = await InvenTreeAPI().uploadFile(
        url,
        attachment,
        method: "POST",
        name: "attachment",
        fields: data
    );

    return response.successful();
  }

  /*
   * Download this attachment file
   */
  Future<void> downloadAttachment() async {
    await InvenTreeAPI().downloadFile(attachment);
  }

}


