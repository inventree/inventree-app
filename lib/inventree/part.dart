import "dart:io";
import "dart:math";

import "package:flutter/material.dart";

import "package:inventree/api.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/part/part_detail.dart";

/*
 * Class representing the PartCategory database model
 */
class InvenTreePartCategory extends InvenTreeModel {
  InvenTreePartCategory() : super();

  InvenTreePartCategory.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  String get URL => "part/category/";

  static const String MODEL_TYPE = "partcategory";

  @override
  List<String> get rolesRequired => ["part"];

  // Navigate to a detail page for this item
  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    // Default implementation does not do anything...
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryDisplayWidget(this)),
    );
  }

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {
      "name": {},
      "description": {},
      "parent": {},
      "structural": {},
    };

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
  int get partcount =>
      (jsondata["part_count"] ?? jsondata["parts"] ?? 0) as int;

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePartCategory.fromJson(json);
}

/*
 * Class representing the PartTestTemplate database model
 */
class InvenTreePartTestTemplate extends InvenTreeModel {
  InvenTreePartTestTemplate() : super();

  InvenTreePartTestTemplate.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  String get URL => "part/test-template/";

  static const String MODEL_TYPE = "parttesttemplate";

  String get key => getString("key");

  String get testName => getString("test_name");

  bool get required => getBool("required");

  bool get requiresValue => getBool("requires_value");

  bool get requiresAttachment => getBool("requires_attachment");

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePartTestTemplate.fromJson(json);

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
 * Class representing the Part database model
 */
class InvenTreePart extends InvenTreeModel {
  InvenTreePart() : super();

  InvenTreePart.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String get URL => "part/";

  static const String MODEL_TYPE = "part";

  @override
  List<String> get rolesRequired => ["part"];

  // Navigate to a detail page for this item
  @override
  Future<Object?> goToDetailPage(BuildContext context) async {
    // Default implementation does not do anything...
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PartDetailWidget(this)),
    );
  }

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
  Map<String, String> defaultFilters() {
    return {"category_detail": "true"};
  }

  // Cached list of stock items
  List<InvenTreeStockItem> stockItems = [];

  int get stockItemCount => stockItems.length;

  // Request stock items for this part
  Future<void> getStockItems(
    BuildContext context, {
    bool showDialog = false,
  }) async {
    await InvenTreeStockItem()
        .list(filters: {"part": "${pk}", "in_stock": "true"})
        .then((var items) {
          stockItems.clear();

          for (var item in items) {
            if (item is InvenTreeStockItem) {
              stockItems.add(item);
            }
          }
        });
  }

  // Request pricing data for this part
  Future<InvenTreePartPricing?> getPricing() async {
    try {
      final response = await InvenTreeAPI().get("/api/part/${pk}/pricing/");
      if (response.isValid()) {
        final pricingData = response.data;

        if (pricingData is Map<String, dynamic>) {
          return InvenTreePartPricing.fromJson(pricingData);
        }
      }
    } catch (e, stackTrace) {
      print("Exception while fetching pricing data for part $pk: $e");
      sentryReportError("getPricing", e, stackTrace);
    }

    return null;
  }

  int get supplierCount => getInt("suppliers", backup: 0);

  // Request supplier parts for this part
  Future<List<InvenTreeSupplierPart>> getSupplierParts() async {
    List<InvenTreeSupplierPart> _supplierParts = [];

    final parts = await InvenTreeSupplierPart().list(
      filters: {"part": "${pk}"},
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
    InvenTreePartTestTemplate().list(filters: {"part": "${pk}"}).then((
      var templates,
    ) {
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

  double get inStock {
    if (jsondata.containsKey("total_in_stock")) {
      return getDouble("total_in_stock");
    } else {
      return getDouble("in_stock");
    }
  }

  String get inStockString => simpleNumberString(inStock);

  // Get the 'available stock' for this Part
  double get unallocatedStock {
    double unallocated = 0;

    // Note that the 'available_stock' was not added until API v35
    if (jsondata.containsKey("unallocated_stock")) {
      unallocated =
          double.tryParse(jsondata["unallocated_stock"].toString()) ?? 0;
    } else {
      unallocated = inStock;
    }

    return max(0, unallocated);
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
  int get usedInCount =>
      jsondata.containsKey("used_in") ? getInt("used_in", backup: 0) : 0;

  bool get isAssembly => getBool("assembly");

  bool get isComponent => getBool("component");

  bool get isPurchaseable => getBool("purchaseable");

  bool get isSalable => getBool("salable");

  bool get isActive => getBool("active");

  bool get isVirtual => getBool("virtual");

  bool get isTemplate => getBool("is_template");

  bool get isTrackable => getBool("trackable");

  bool get isTestable => getBool("testable");

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
  String get _image => getString("image");

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
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePart.fromJson(json);
}

class InvenTreePartPricing extends InvenTreeModel {
  InvenTreePartPricing() : super();

  InvenTreePartPricing.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  List<String> get rolesRequired => ["part"];

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) =>
      InvenTreePartPricing.fromJson(json);

  // Price data accessors
  String get currency => getString("currency", backup: "USD");

  double? get overallMin => getDoubleOrNull("overall_min");
  double? get overallMax => getDoubleOrNull("overall_max");

  double? get overrideMin => getDoubleOrNull("override_min");
  double? get overrideMax => getDoubleOrNull("override_max");

  String get overrideMinCurrency =>
      getString("override_min_currency", backup: currency);
  String get overrideMaxCurrency =>
      getString("override_max_currency", backup: currency);

  double? get bomCostMin => getDoubleOrNull("bom_cost_min");
  double? get bomCostMax => getDoubleOrNull("bom_cost_max");

  double? get purchaseCostMin => getDoubleOrNull("purchase_cost_min");
  double? get purchaseCostMax => getDoubleOrNull("purchase_cost_max");

  double? get internalCostMin => getDoubleOrNull("internal_cost_min");
  double? get internalCostMax => getDoubleOrNull("internal_cost_max");

  double? get supplierPriceMin => getDoubleOrNull("supplier_price_min");
  double? get supplierPriceMax => getDoubleOrNull("supplier_price_max");

  double? get variantCostMin => getDoubleOrNull("variant_cost_min");
  double? get variantCostMax => getDoubleOrNull("variant_cost_max");

  double? get salePriceMin => getDoubleOrNull("sale_price_min");
  double? get salePriceMax => getDoubleOrNull("sale_price_max");

  double? get saleHistoryMin => getDoubleOrNull("sale_history_min");
  double? get saleHistoryMax => getDoubleOrNull("sale_history_max");
}
