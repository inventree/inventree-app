import "dart:io";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/company.dart";
import "package:flutter/material.dart";
import "package:inventree/l10.dart";

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
  Map<String, dynamic> formFields() {

    Map<String, dynamic> fields = {
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

  String get pathstring => (jsondata["pathstring"] ?? "") as String;

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
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var cat = InvenTreePartCategory.fromJson(json);

    return cat;
  }
}


/*
 * Class representing the PartTestTemplate database model
 */
class InvenTreePartTestTemplate extends InvenTreeModel {

  InvenTreePartTestTemplate() : super();

  InvenTreePartTestTemplate.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "part/test-template/";

  String get key => (jsondata["key"] ?? "") as String;

  String get testName => (jsondata["test_name"] ?? "") as String;

  bool get required => (jsondata["required"] ?? false) as bool;

  bool get requiresValue => (jsondata["requires_value"] ?? false) as bool;

  bool get requiresAttachment => (jsondata["requires_attachment"] ?? false) as bool;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var template = InvenTreePartTestTemplate.fromJson(json);

    return template;
  }

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
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePartParameter.fromJson(json);
  }

  @override
  Map<String, dynamic> formFields() {
    return {};
  }

  @override
  String get name => (jsondata["template_detail"]?["name"] ?? "") as String;

  @override
  String get description => (jsondata["template_detail"]?["description"] ?? "") as String;

  String get value => jsondata["data"] as String;

  String get valueString {
    String v = value;

    if (units.isNotEmpty) {
      v += " ";
      v += units;
    }

    return v;
  }

  String get units => (jsondata["template_detail"]?["units"] ?? "") as String;
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
  Map<String, dynamic> formFields() {
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

  int get supplierCount => (jsondata["suppliers"] ?? 0) as int;

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

    // Get the number of stock on order for this Part
    double get onOrder => double.tryParse(jsondata["ordering"].toString()) ?? 0;

    String get onOrderString {

      return simpleNumberString(onOrder);
    }

    // Get the stock count for this Part
    double get inStock => double.tryParse(jsondata["in_stock"].toString()) ?? 0;

    String get inStockString {

      String q = simpleNumberString(inStock);

      return q;
    }

    // Get the 'available stock' for this Part
    double get unallocatedStock {

      // Note that the 'available_stock' was not added until API v35
      if (jsondata.containsKey("unallocated_stock")) {
        return double.tryParse(jsondata["unallocated_stock"].toString()) ?? 0;
      } else {
        return inStock;
      }
    }

    String get unallocatedStockString {
      String q = simpleNumberString(unallocatedStock);

      return q;
    }

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

    String get units => (jsondata["units"] ?? "") as String;

    // Get the ID of the Part that this part is a variant of (or null)
    int? get variantOf => jsondata["variant_of"] as int?;

    // Get the number of units being build for this Part
    double get building => double.tryParse(jsondata["building"].toString()) ?? 0;

    // Get the number of BOMs this Part is used in (if it is a component)
    int get usedInCount => (jsondata["used_in"] ?? 0) as int;

    bool get isAssembly => (jsondata["assembly"] ?? false) as bool;

    bool get isComponent => (jsondata["component"] ?? false) as bool;

    bool get isPurchaseable => (jsondata["purchaseable"] ?? false) as bool;

    bool get isSalable => (jsondata["salable"] ?? false) as bool;

    bool get isActive => (jsondata["active"] ?? false) as bool;

    bool get isVirtual => (jsondata["virtual"] ?? false) as bool;

    bool get isTrackable => (jsondata["trackable"] ?? false) as bool;

    // Get the IPN (internal part number) for the Part instance
    String get IPN => (jsondata["IPN"] ?? "") as String;

    // Get the revision string for the Part instance
    String get revision => (jsondata["revision"] ?? "") as String;

    // Get the category ID for the Part instance (or "null" if does not exist)
    int get categoryId => (jsondata["category"] ?? -1) as int;

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
    String get _image  => (jsondata["image"] ?? "") as String;

    // Get the thumbnail URL for the Part instance
    String get _thumbnail => (jsondata["thumbnail"] ?? "") as String;

    // Return the fully-qualified name for the Part instance
    String get fullname {

      String fn = (jsondata["full_name"] ?? "") as String;

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
    bool get starred => (jsondata["starred"] ?? false) as bool;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

    var part = InvenTreePart.fromJson(json);

    return part;
  }
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
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    return InvenTreePartAttachment.fromJson(json);
  }

}
