import "dart:io";

import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";


/*
 * Class representing the PartCategory database model
 */
class InvenTreePartCategory extends InvenTreeModel {

  InvenTreePartCategory() : super();

  InvenTreePartCategory.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "part/category/";

  @override
  List<String> get rolesRequired => ["part_category"];

  @override
  Map<String, Map<String, dynamic>> formFields() {

    Map<String, Map<String, dynamic>> fields = {
      "name": {},
      "description": {},
      "parent": {},
      "structural": {},
    };

    if (!api.supportsStructuralCategories) {
      fields.remove("structural");
    }

    return fields;
  }

  String get pathstring => getString("pathstring");
  
  String get parentPathString {

    List<String> psplit = pathstring.split("/");

    if (psplit.isNotEmpty) {
      psplit.removeLast();
    }

    String p = psplit.join("/");

    if (p.isEmpty) {
      p = L10().partCategoryTopLevel;
    }

    return p;
  }

  // Return the number of parts in this category
  // Note that the API changed from 'parts' to 'part_count' (v69)
  int get partcount => (jsondata["part_count"] ?? jsondata["parts"] ?? 0) as int;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePartCategory.fromJson(json);
}


/*
 * Class representing the PartTestTemplate database model
 */
class InvenTreePartTestTemplate extends InvenTreeModel {

  InvenTreePartTestTemplate() : super();

  InvenTreePartTestTemplate.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "part/test-template/";

  String get key => getString("key");

  String get testName => getString("test_name");

  bool get required => getBool("required");
  
  bool get requiresValue => getBool("requires_value");

  bool get requiresAttachment => getBool("requires_attachment");

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePartTestTemplate.fromJson(json);

  bool passFailStatus() {

    var result = latestResult();

    if (result == null) {
      return false;
    }

    return result.result;
  }

  // List of test results associated with this template
  List<InvenTreeStockItemTestResult> results = [];

  // Return the most recent test result recorded against this template
  InvenTreeStockItemTestResult? latestResult() {
    if (results.isEmpty) {
      return null;
    }

    return results.last;
  }

}

/*
 Class representing the PartParameter database model
 */
class InvenTreePartParameter extends InvenTreeModel {

  InvenTreePartParameter() : super();

  InvenTreePartParameter.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "part/parameter/";

  @override
  List<String> get rolesRequired => ["part"];

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePartParameter.fromJson(json);

  @override
  Map<String, Map<String, dynamic>> formFields() {

    Map<String, Map<String, dynamic>> fields = {
      "header": {
        "type": "string",
        "read_only": true,
        "label": name,
        "help_text": description,
        "value": "",
      },
      "data": {
        "type": "string",
      }
    };

    return fields;
  }

  @override
  String get name => getString("name", subKey: "template_detail");

  @override
  String get description => getString("description", subKey: "template_detail");
  
  String get value => getString("data");
  
  String get valueString {
    String v = value;

    if (units.isNotEmpty) {
      v += " ";
      v += units;
    }

    return v;
  }

  bool get as_bool => value.toLowerCase() == "true";

  String get units => getString("units", subKey: "template_detail");
  
  bool get is_checkbox => getBool("checkbox", subKey: "template_detail", backup: false);
}

/*
 * Class representing the Part database model
 */
class InvenTreePart extends InvenTreeModel {

  InvenTreePart() : super();

  InvenTreePart.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "part/";

  @override
  List<String> get rolesRequired => ["part"];

  @override
  Map<String, Map<String, dynamic>> formFields() {
    return {
      "name": {},
      "description": {},
      "IPN": {},
      "revision": {},
      "keywords": {},
      "link": {},

      "category": {},

      "default_location": {},

      "units": {},

      // Checkbox fields
      "active": {},
      "assembly": {},
      "component": {},
      "purchaseable": {},
      "salable": {},
      "trackable": {},
      "is_template": {},
      "virtual": {},
    };
  }

  @override
  Map<String, String> defaultListFilters() {
    return {
      "location_detail": "true",
    };
  }

  @override
  Map<String, String> defaultGetFilters() {
    return {
      "category_detail": "true",   // Include category detail information
    };
  }

  // Cached list of stock items
  List<InvenTreeStockItem> stockItems = [];

  int get stockItemCount => stockItems.length;

  // Request stock items for this part
  Future<void> getStockItems(BuildContext context, {bool showDialog=false}) async {

    await InvenTreeStockItem().list(
      filters: {
        "part": "${pk}",
        "in_stock": "true",
      },
    ).then((var items) {
      stockItems.clear();

      for (var item in items) {
        if (item is InvenTreeStockItem) {
          stockItems.add(item);
        }
      }
    });
  }

  int get supplierCount => getInt("suppliers", backup: 0);
  
  // Request supplier parts for this part
  Future<List<InvenTreeSupplierPart>> getSupplierParts() async {
    List<InvenTreeSupplierPart> _supplierParts = [];

    final parts = await InvenTreeSupplierPart().list(
        filters: {
          "part": "${pk}",
        }
    );

    for (var result in parts) {
      if (result is InvenTreeSupplierPart) {
        _supplierParts.add(result);
      }
    }

    return _supplierParts;
  }

  // Cached list of test templates
  List<InvenTreePartTestTemplate> testingTemplates = [];

  int get testTemplateCount => testingTemplates.length;

  // Request test templates from the serve
  Future<void> getTestTemplates() async {

    InvenTreePartTestTemplate().list(
      filters: {
        "part": "${pk}",
      },
    ).then((var templates) {

      testingTemplates.clear();

      for (var t in templates) {
        if (t is InvenTreePartTestTemplate) {
          testingTemplates.add(t);
        }
      }
    });
  }

  int? get defaultLocation => jsondata["default_location"] as int?;

  double get onOrder => getDouble("ordering");

  String get onOrderString => simpleNumberString(onOrder);

  double get inStock => getDouble("in_stock");

  String get inStockString => simpleNumberString(inStock);

  // Get the 'available stock' for this Part
  double get unallocatedStock {

    // Note that the 'available_stock' was not added until API v35
    if (jsondata.containsKey("unallocated_stock")) {
      return double.tryParse(jsondata["unallocated_stock"].toString()) ?? 0;
    } else {
      return inStock;
    }
  }

    String get unallocatedStockString => simpleNumberString(unallocatedStock);

    String stockString({bool includeUnits = true}) {
      String q = unallocatedStockString;

      if (unallocatedStock != inStock) {
        q += " / ${inStockString}";
      }

      if (includeUnits && units.isNotEmpty) {
        q += " ${units}";
      }

      return q;
    }

    String get units => getString("units");

    // Get the ID of the Part that this part is a variant of (or null)
    int? get variantOf => jsondata["variant_of"] as int?;

    // Get the number of units being build for this Part
    double get building => getDouble("building");

    // Get the number of BOMs this Part is used in (if it is a component)
    int get usedInCount => jsondata.containsKey("used_in") ? getInt("used_in", backup: 0) : 0;

    bool get isAssembly => getBool("assembly");

    bool get isComponent => getBool("component");

    bool get isPurchaseable => getBool("purchaseable");

    bool get isSalable => getBool("salable");

    bool get isActive => getBool("active");

    bool get isVirtual => getBool("virtual");

    bool get isTrackable => getBool("trackable");

    // Get the IPN (internal part number) for the Part instance
    String get IPN => getString("IPN");

    // Get the revision string for the Part instance
    String get revision => getString("revision");

    // Get the category ID for the Part instance (or "null" if does not exist)
    int get categoryId => getInt("category");

    // Get the category name for the Part instance
    String get categoryName {
      // Inavlid category ID
      if (categoryId <= 0) return "";

      if (!jsondata.containsKey("category_detail")) return "";

      return (jsondata["category_detail"]?["name"] ?? "") as String;
    }

    // Get the category description for the Part instance
    String get categoryDescription {
      // Invalid category ID
      if (categoryId <= 0) return "";

      if (!jsondata.containsKey("category_detail")) return "";

      return (jsondata["category_detail"]?["description"] ?? "") as String;
    }
    // Get the image URL for the Part instance
    String get _image  => getString("image");

    // Get the thumbnail URL for the Part instance
    String get _thumbnail => getString("thumbnail");

    // Return the fully-qualified name for the Part instance
    String get fullname {

      String fn = getString("full_name");

      if (fn.isNotEmpty) return fn;

      List<String> elements = [];

      if (IPN.isNotEmpty) elements.add(IPN);

      elements.add(name);

      if (revision.isNotEmpty) elements.add(revision);

      return elements.join(" | ");
    }

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

    Future<bool> uploadImage(File image) async {
      // Upload file against this part
      final APIResponse response = await InvenTreeAPI().uploadFile(
        url,
        image,
        method: "PATCH",
        name: "image",
      );

      return response.successful();
    }

    // Return the "starred" status of this part
    bool get starred => getBool("starred");

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePart.fromJson(json);
}

/*
 * Class representing an attachment file against a Part object
 */
class InvenTreePartAttachment extends InvenTreeAttachment {

  InvenTreePartAttachment() : super();

  InvenTreePartAttachment.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get REFERENCE_FIELD => "part";

  @override
  String get URL => "part/attachment/";

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreePartAttachment.fromJson(json);

}
