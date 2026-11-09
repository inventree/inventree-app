/*
 * Unit tests for model classes constructed from JSON data
 *
 * These tests do not require a connection to the server
 */

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:flutter_test/flutter_test.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/attachment.dart";
import "package:inventree/inventree/bom.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/notes.dart";
import "package:inventree/inventree/notification.dart";
import "package:inventree/inventree/orders.dart";
import "package:inventree/inventree/parameter.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/project_code.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";

void main() {
  group("Model Accessors:", () {
    test("Empty Data", () async {
      final model = InvenTreeModel.fromJson({});

      expect(model.pk, equals(-1));
      expect(model.name, equals(""));
      expect(model.description, equals(""));
      expect(model.getString("missing", backup: "x"), equals("x"));
      expect(model.getInt("missing", backup: 7), equals(7));
      expect(model.getDouble("missing"), equals(0.0));
      expect(model.getDoubleOrNull("missing"), isNull);
      expect(model.getBool("missing"), isFalse);
      expect(model.getBool("missing", backup: true), isTrue);
      expect(model.getDate("missing"), isNull);
      expect(model.getDateString("missing"), equals(""));
      expect(model.getMap("missing"), isEmpty);
      expect(model.link, equals(""));
      expect(model.hasLink, isFalse);
      expect(model.customIcon, isNull);
      expect(model.customBarcode, equals(""));
      expect(model.reloadedWithin(const Duration(days: 1)), isFalse);
    });

    test("Typed Values", () async {
      final model = InvenTreeModel.fromJson({
        "pk": 12,
        "name": "Widget",
        "count": "42",
        "bad_int": "abc",
        "ratio": "1.5",
        "bad_double": "x",
        "flag": "True",
        "not_flag": "yes",
        "null_value": null,
        "date": "2024-03-07T10:15:00Z",
        "detail": {"name": "Sub", "count": 3},
      });

      expect(model.pk, equals(12));
      expect(model.pkString, equals("12"));
      expect(model.name, equals("Widget"));

      expect(model.getInt("count"), equals(42));
      expect(model.getInt("bad_int"), equals(-1));
      expect(model.getDouble("ratio"), equals(1.5));
      expect(model.getDoubleOrNull("bad_double"), isNull);
      expect(model.getBool("flag"), isTrue);
      expect(model.getBool("not_flag"), isFalse);

      // Explicit null values return the backup
      expect(model.getString("null_value", backup: "b"), equals("b"));
      expect(model.getInt("null_value", backup: 3), equals(3));
      expect(model.getBool("null_value", backup: true), isTrue);
      expect(model.getMap("null_value"), isEmpty);

      expect(model.getDate("date")?.year, equals(2024));
      expect(model.getDateString("date"), equals("2024-03-07"));

      // Sub-key lookups
      expect(model.getString("name", subKey: "detail"), equals("Sub"));
      expect(model.getInt("count", subKey: "detail"), equals(3));
      expect(model.getMap("detail")["name"], equals("Sub"));
      expect(
        model.getString("name", subKey: "missing", backup: "none"),
        equals("none"),
      );

      model.setValue("name", "Gadget");
      expect(model.name, equals("Gadget"));
    });

    test("Status", () async {
      var model = InvenTreeModel.fromJson({"status": 10});

      expect(model.status, equals(10));
      expect(model.hasCustomStatus, isFalse);

      model = InvenTreeModel.fromJson({"status": 10, "status_custom_key": 101});

      expect(model.logicalStatus, equals(10));
      expect(model.customStatus, equals(101));
      expect(model.status, equals(101));
    });

    test("Link", () async {
      expect(
        InvenTreeModel.fromJson({"link": "https://a.com"}).link,
        equals("https://a.com"),
      );

      // Legacy API used "URL"
      final legacy = InvenTreeModel.fromJson({"URL": "https://b.com"});
      expect(legacy.link, equals("https://b.com"));
      expect(legacy.hasLink, isTrue);
    });

    test("Custom Icon", () async {
      expect(InvenTreeModel.fromJson({"icon": "  "}).customIcon, isNull);
      expect(InvenTreeModel.fromJson({"icon": "fa:box"}).customIcon, isNull);
      expect(InvenTreeModel.fromJson({"icon": "ti:"}).customIcon, isNull);
      expect(
        InvenTreeModel.fromJson({"icon": "ti:not-an-icon:outline"}).customIcon,
        isNull,
      );
      expect(
        InvenTreeModel.fromJson({"icon": "ti:box:outline"}).customIcon,
        isNotNull,
      );
      expect(
        InvenTreeModel.fromJson({"icon": "ti:arrow-left:outline"}).customIcon,
        isNotNull,
      );
    });

    test("Custom Barcode", () async {
      expect(
        InvenTreeModel.fromJson({
          "uid": "abc",
          "barcode_hash": "def",
        }).customBarcode,
        equals("abc"),
      );
      expect(
        InvenTreeModel.fromJson({
          "barcode_hash": "def",
          "barcode": "ghi",
        }).customBarcode,
        equals("def"),
      );
      expect(
        InvenTreeModel.fromJson({"barcode": "ghi"}).customBarcode,
        equals("ghi"),
      );
    });

    test("Detail URL", () async {
      final part = InvenTreePart.fromJson({"pk": 5});
      expect(part.url, equals("part/5/"));

      final item = InvenTreeStockItem.fromJson({"pk": 9});
      expect(item.url, equals("stock/9/"));
    });

    test("Reloaded Within", () async {
      final model = InvenTreeModel.fromJson({});

      model.lastReload = DateTime.now();
      expect(model.reloadedWithin(const Duration(minutes: 1)), isTrue);

      model.lastReload = DateTime.now().subtract(const Duration(hours: 1));
      expect(model.reloadedWithin(const Duration(minutes: 1)), isFalse);
    });
  });

  group("Part Category:", () {
    test("Path", () async {
      var category = InvenTreePartCategory.fromJson({
        "pathstring": "Electronics/Passives/Resistors",
      });

      expect(category.parentPathString, equals("Electronics/Passives"));

      category = InvenTreePartCategory.fromJson({"pathstring": "Electronics"});

      expect(category.parentPathString, equals(L10().partCategoryTopLevel));
    });

    test("Part Count", () async {
      expect(InvenTreePartCategory.fromJson({}).partcount, equals(0));
      expect(
        InvenTreePartCategory.fromJson({"part_count": 4}).partcount,
        equals(4),
      );

      // Legacy API used "parts"
      expect(InvenTreePartCategory.fromJson({"parts": 3}).partcount, equals(3));
    });
  });

  group("Part:", () {
    test("Full Name", () async {
      expect(
        InvenTreePart.fromJson({
          "full_name": "IPN | Name",
          "name": "x",
        }).fullname,
        equals("IPN | Name"),
      );

      expect(
        InvenTreePart.fromJson({"name": "Widget"}).fullname,
        equals("Widget"),
      );

      expect(
        InvenTreePart.fromJson({
          "name": "Widget",
          "IPN": "W-001",
          "revision": "B",
        }).fullname,
        equals("W-001 | Widget | B"),
      );
    });

    test("Stock", () async {
      var part = InvenTreePart.fromJson({"in_stock": 10});

      expect(part.inStock, equals(10));
      expect(part.unallocatedStock, equals(10));
      expect(part.stockString(), equals("10"));

      part = InvenTreePart.fromJson({
        "in_stock": 1,
        "total_in_stock": 12.5,
        "unallocated_stock": "4",
        "units": "m",
        "ordering": 3,
      });

      expect(part.inStock, equals(12.5));
      expect(part.inStockString, equals("12.5"));
      expect(part.unallocatedStock, equals(4));
      expect(part.stockString(), equals("4 / 12.5 m"));
      expect(part.stockString(includeUnits: false), equals("4 / 12.5"));
      expect(part.onOrderString, equals("3"));

      // Available stock cannot be negative
      part = InvenTreePart.fromJson({"in_stock": 1, "unallocated_stock": -5});

      expect(part.unallocatedStock, equals(0));
    });

    test("Category", () async {
      final detail = {"name": "Resistors", "description": "Fixed resistors"};

      var part = InvenTreePart.fromJson({
        "category": 4,
        "category_detail": detail,
      });

      expect(part.categoryId, equals(4));
      expect(part.categoryName, equals("Resistors"));
      expect(part.categoryDescription, equals("Fixed resistors"));

      // Missing detail
      part = InvenTreePart.fromJson({"category": 4});
      expect(part.categoryName, equals(""));
      expect(part.categoryDescription, equals(""));

      // No category
      part = InvenTreePart.fromJson({"category_detail": detail});
      expect(part.categoryName, equals(""));
      expect(part.categoryDescription, equals(""));
    });

    test("Images", () async {
      var part = InvenTreePart.fromJson({});
      expect(part.image, equals(InvenTreeAPI.staticImage));
      expect(part.thumbnail, equals(InvenTreeAPI.staticThumb));

      part = InvenTreePart.fromJson({"image": "/media/a.png"});
      expect(part.image, equals("/media/a.png"));
      expect(part.thumbnail, equals("/media/a.png"));

      part = InvenTreePart.fromJson({"thumbnail": "/media/a.thumb.png"});
      expect(part.image, equals("/media/a.thumb.png"));
      expect(part.thumbnail, equals("/media/a.thumb.png"));
    });

    test("Attributes", () async {
      final part = InvenTreePart.fromJson({
        "assembly": true,
        "component": false,
        "purchaseable": true,
        "salable": false,
        "active": true,
        "virtual": false,
        "is_template": true,
        "trackable": true,
        "testable": false,
        "starred": true,
        "used_in": 6,
        "variant_of": 2,
        "default_location": 8,
      });

      expect(part.isAssembly, isTrue);
      expect(part.isComponent, isFalse);
      expect(part.isPurchaseable, isTrue);
      expect(part.isSalable, isFalse);
      expect(part.isActive, isTrue);
      expect(part.isVirtual, isFalse);
      expect(part.isTemplate, isTrue);
      expect(part.isTrackable, isTrue);
      expect(part.isTestable, isFalse);
      expect(part.starred, isTrue);
      expect(part.usedInCount, equals(6));
      expect(part.variantOf, equals(2));
      expect(part.defaultLocation, equals(8));

      expect(InvenTreePart.fromJson({}).usedInCount, equals(0));
    });

    test("Pricing", () async {
      var pricing = InvenTreePartPricing.fromJson({});

      expect(pricing.currency, equals("USD"));
      expect(pricing.overallMin, isNull);

      pricing = InvenTreePartPricing.fromJson({
        "currency": "AUD",
        "overall_min": "1.25",
        "overall_max": 3,
      });

      expect(pricing.currency, equals("AUD"));
      expect(pricing.overallMin, equals(1.25));
      expect(pricing.overallMax, equals(3));
    });
  });

  group("Stock Item:", () {
    test("Quantity", () async {
      var item = InvenTreeStockItem.fromJson({"quantity": 10});

      expect(item.isSerialized(), isFalse);
      expect(item.quantityString(), equals("10"));
      expect(item.serialOrQuantityDisplay(), equals("10"));
      expect(item.displayQuantity, equals("10"));

      item = InvenTreeStockItem.fromJson({
        "quantity": 10,
        "allocated": 4,
        "part_detail": {"units": "kg"},
      });

      expect(item.available, equals(6));
      expect(item.quantityString(), equals("6 / 10 kg"));
      expect(item.quantityString(includeUnits: false), equals("6 / 10"));
      expect(item.serialOrQuantityDisplay(), equals("6.0 / 10.0"));
      expect(item.displayQuantity, equals("10 kg"));
    });

    test("Serial Number", () async {
      var item = InvenTreeStockItem.fromJson({"quantity": 1, "serial": "123"});

      expect(item.isSerialized(), isTrue);
      expect(item.serialOrQuantityDisplay(), equals("SN 123"));
      expect(item.displayQuantity, equals("SN: 123"));

      // Serial number with quantity > 1 is not considered serialized
      item = InvenTreeStockItem.fromJson({"quantity": 2, "serial": "123"});
      expect(item.isSerialized(), isFalse);
    });

    test("Part Information", () async {
      var item = InvenTreeStockItem.fromJson({
        "part_detail": {
          "full_name": "Widget | A",
          "description": "A widget",
          "thumbnail": "/media/w.thumb.png",
        },
      });

      expect(item.partName, equals("Widget | A"));
      expect(item.partDescription, equals("A widget"));
      expect(item.partImage, equals("/media/w.thumb.png"));
      expect(item.partThumbnail, equals("/media/w.thumb.png"));

      // Legacy API fields
      item = InvenTreeStockItem.fromJson({
        "part__name": "Old",
        "part__description": "Old desc",
        "part__thumbnail": "/media/old.png",
      });

      expect(item.partName, equals("Old"));
      expect(item.partDescription, equals("Old desc"));
      expect(item.partImage, equals("/media/old.png"));
      expect(item.partThumbnail, equals("/media/old.png"));

      // Image used as thumbnail backup
      item = InvenTreeStockItem.fromJson({
        "part_detail": {"image": "/media/w.png"},
      });

      expect(item.partThumbnail, equals("/media/w.png"));

      // No image at all
      expect(
        InvenTreeStockItem.fromJson({}).partThumbnail,
        equals(InvenTreeAPI.staticThumb),
      );
    });

    test("Supplier Information", () async {
      var item = InvenTreeStockItem.fromJson({
        "supplier_part": 3,
        "supplier_part_detail": {
          "SKU": "SKU-1",
          "supplier_detail": {"image": "/media/s1.png"},
        },
        "supplier_detail": {"supplier_name": "ACME"},
      });

      expect(item.supplierPartId, equals(3));
      expect(item.supplierSKU, equals("SKU-1"));
      expect(item.supplierImage, equals("/media/s1.png"));
      expect(item.supplierName, equals("ACME"));

      item = InvenTreeStockItem.fromJson({
        "supplier_detail": {"image": "/media/s2.png"},
      });

      expect(item.supplierImage, equals("/media/s2.png"));
      expect(InvenTreeStockItem.fromJson({}).supplierImage, equals(""));
    });

    test("Location", () async {
      var item = InvenTreeStockItem.fromJson({});

      expect(item.locationName, equals("Unknown Location"));
      expect(item.locationPathString, equals(L10().locationNotSet));

      item = InvenTreeStockItem.fromJson({
        "location": 7,
        "location_detail": {"name": "Shelf", "pathstring": "Store/Shelf"},
      });

      expect(item.locationId, equals(7));
      expect(item.locationName, equals("Shelf"));
      expect(item.locationPathString, equals("Store/Shelf"));

      // Legacy name, and no pathstring
      item = InvenTreeStockItem.fromJson({
        "location": 7,
        "location_detail": {},
        "location__name": "Bin",
      });

      expect(item.locationName, equals("Bin"));
      expect(item.locationPathString, equals("Bin"));
    });

    test("Purchase Price", () async {
      var item = InvenTreeStockItem.fromJson({});

      expect(item.purchasePrice, isNull);
      expect(item.hasPurchasePrice, isFalse);

      item = InvenTreeStockItem.fromJson({
        "purchase_price": "2.50",
        "purchase_price_currency": "AUD",
      });

      expect(item.purchasePrice, equals(2.5));
      expect(item.hasPurchasePrice, isTrue);
      expect(item.purchasePriceCurrency, equals("AUD"));

      item = InvenTreeStockItem.fromJson({"purchase_price": "0"});
      expect(item.hasPurchasePrice, isFalse);
    });

    test("Attributes", () async {
      var item = InvenTreeStockItem.fromJson({});

      expect(item.isInStock, isTrue);
      expect(item.hasSalesOrder, isFalse);
      expect(item.hasCustomer, isFalse);

      item = InvenTreeStockItem.fromJson({
        "in_stock": false,
        "sales_order": 4,
        "customer": 2,
        "stale": true,
        "expired": false,
        "expiry_date": "2025-01-31",
        "batch": "B1",
        "packaging": "Reel",
      });

      expect(item.isInStock, isFalse);
      expect(item.hasSalesOrder, isTrue);
      expect(item.hasCustomer, isTrue);
      expect(item.stale, isTrue);
      expect(item.expired, isFalse);
      expect(item.expiryDateString, equals("2025-01-31"));
      expect(item.batch, equals("B1"));
      expect(item.packaging, equals("Reel"));
    });
  });

  group("Orders:", () {
    test("Order", () async {
      var order = InvenTreeOrder.fromJson({});

      expect(order.lineItemCount, equals(0));
      expect(order.complete, isTrue);
      expect(order.totalPrice, isNull);
      expect(order.totalPriceCurrency, equals(""));
      expect(order.hasProjectCode, isFalse);

      order = InvenTreeOrder.fromJson({
        "reference": "PO-0001",
        "line_items": 5,
        "completed_lines": 2,
        "total_price": "100.5",
        "order_currency": "AUD",
        "total_price_currency": "USD",
        "target_date": "2025-06-01",
        "project_code_detail": {"code": "PRJ", "description": "Project"},
        "responsible_detail": {"name": "team", "label": "Team"},
      });

      expect(order.reference, equals("PO-0001"));
      expect(order.complete, isFalse);
      expect(order.totalPrice, equals(100.5));
      expect(order.totalPriceCurrency, equals("AUD"));
      expect(order.targetDate, equals("2025-06-01"));
      expect(order.hasProjectCode, isTrue);
      expect(order.projectCodeDescription, equals("Project"));
      expect(order.responsibleName, equals("team"));
      expect(order.responsibleLabel, equals("Team"));

      // Legacy currency field
      order = InvenTreeOrder.fromJson({"total_price_currency": "USD"});
      expect(order.totalPriceCurrency, equals("USD"));
    });

    test("Order Line", () async {
      var line = InvenTreeOrderLine.fromJson({"quantity": 3});

      expect(line.quantity, equals(3));
      expect(line.part, isNull);
      expect(line.partImage, equals(""));

      line = InvenTreeOrderLine.fromJson({
        "part_detail": {
          "pk": 4,
          "name": "Widget",
          "description": "A widget",
          "image": "/media/w.png",
        },
      });

      expect(line.part?.name, equals("Widget"));
      expect(line.partId, equals(4));
      expect(line.partName, equals("Widget"));
      expect(line.partDescription, equals("A widget"));
      expect(line.partImage, equals("/media/w.png"));
    });

    test("Extra Line", () async {
      final line = InvenTreeExtraLineItem.fromJson({
        "order": 2,
        "quantity": "1.5",
        "price": "10",
        "price_currency": "EUR",
      });

      expect(line.orderId, equals(2));
      expect(line.quantity, equals(1.5));
      expect(line.price, equals(10));
      expect(line.priceCurrency, equals("EUR"));
      expect(line.formFields()["order"]?["hidden"], isTrue);
    });
  });

  group("Attachment:", () {
    test("Empty Data", () async {
      final attachment = InvenTreeAttachment.fromJson({});

      expect(attachment.URL, equals("attachment/"));
      expect(attachment.attachment, equals(""));
      expect(attachment.hasAttachment, isFalse);
      expect(attachment.filename, equals(""));
      expect(attachment.icon, equals(TablerIcons.file));
      expect(attachment.comment, equals(""));
      expect(attachment.uploadDate, isNull);
      expect(attachment.modelType, equals(""));
      expect(attachment.modelId, equals(-1));

      // No link, so the 'link' field is not displayed
      expect(attachment.formFields().keys, equals(["comment"]));

      expect(
        attachment.createFromJson({"pk": 3}),
        isA<InvenTreeAttachment>().having((a) => a.pk, "pk", 3),
      );
    });

    test("File Attachment", () async {
      final attachment = InvenTreeAttachment.fromJson({
        "attachment": "/media/attachments/part/7/Datasheet.PDF",
        "comment": "A datasheet",
        "upload_date": "2024-03-15",
        "model_type": "part",
        "model_id": 7,
      });

      expect(attachment.hasAttachment, isTrue);
      expect(attachment.filename, equals("Datasheet.PDF"));
      expect(attachment.icon, equals(TablerIcons.file_type_pdf));
      expect(attachment.comment, equals("A datasheet"));
      expect(attachment.uploadDate, equals(DateTime(2024, 3, 15)));
      expect(attachment.modelType, equals("part"));
      expect(attachment.modelId, equals(7));
      expect(attachment.formFields().keys, equals(["comment"]));
    });

    test("Link Attachment", () async {
      final attachment = InvenTreeAttachment.fromJson({
        "link": "https://inventree.org",
        "upload_date": null,
      });

      expect(attachment.hasAttachment, isFalse);
      expect(attachment.formFields().keys, equals(["link", "comment"]));

      // Null (or invalid) dates are not parsed
      expect(attachment.uploadDate, isNull);
      expect(
        InvenTreeAttachment.fromJson({"upload_date": "junk"}).uploadDate,
        isNull,
      );
    });

    test("File Icons", () async {
      final Map<String, IconData> icons = {
        "report.pdf": TablerIcons.file_type_pdf,
        "data.csv": TablerIcons.file_type_csv,
        "notes.doc": TablerIcons.file_type_doc,
        "notes.docx": TablerIcons.file_type_doc,
        "sheet.xls": TablerIcons.file_type_xls,
        "sheet.XLSX": TablerIcons.file_type_xls,
        "photo.png": TablerIcons.file_type_jpg,
        "photo.jpg": TablerIcons.file_type_jpg,
        "anim.gif": TablerIcons.file_type_jpg,
        "image.bmp": TablerIcons.file_type_jpg,
        "logo.svg": TablerIcons.file_type_jpg,
        "archive.zip": TablerIcons.file,
        "no_extension": TablerIcons.file,
      };

      for (final entry in icons.entries) {
        final attachment = InvenTreeAttachment.fromJson({
          "attachment": "/media/attachments/${entry.key}",
        });

        expect(attachment.icon, equals(entry.value), reason: entry.key);
      }
    });
  });

  group("Notification:", () {
    test("Accessors", () async {
      final notification = InvenTreeNotification.fromJson({
        "pk": 12,
        "message": "Stock is low",
        "creation": "2024-05-01T10:30:00",
      });

      expect(notification.URL, equals("notifications/"));
      expect(notification.defaultListFilters(), equals({"read": "false"}));
      expect(notification.message, equals("Stock is low"));
      expect(notification.creationDate, equals(DateTime(2024, 5, 1, 10, 30)));

      expect(
        notification.createFromJson({"pk": 1}),
        isA<InvenTreeNotification>(),
      );
    });

    test("Missing Date", () async {
      expect(InvenTreeNotification.fromJson({}).creationDate, isNull);
      expect(
        InvenTreeNotification.fromJson({"creation": null}).creationDate,
        isNull,
      );
      expect(
        InvenTreeNotification.fromJson({"creation": "junk"}).creationDate,
        isNull,
      );
      expect(InvenTreeNotification.fromJson({}).message, equals(""));
    });
  });

  group("Project Code:", () {
    test("Accessors", () async {
      final code = InvenTreeProjectCode.fromJson({
        "pk": 4,
        "code": "PRJ-001",
        "description": "Test project",
      });

      expect(InvenTreeProjectCode.MODEL_TYPE, equals("projectcode"));
      expect(code.URL, equals("project-code/"));
      expect(code.code, equals("PRJ-001"));
      expect(code.description, equals("Test project"));
      expect(code.formFields().keys, equals(["code", "description"]));
      expect(InvenTreeProjectCode().code, equals(""));

      expect(
        code.createFromJson({"pk": 5}),
        isA<InvenTreeProjectCode>().having((c) => c.pk, "pk", 5),
      );
    });
  });

  group("Parameter:", () {
    test("Accessors", () async {
      final parameter = InvenTreeParameter.fromJson({
        "pk": 9,
        "data": "12",
        "model_type": "part",
        "model_id": 3,
        "template_detail": {
          "name": "Length",
          "description": "Overall length",
          "units": "mm",
          "checkbox": false,
        },
      });

      expect(parameter.URL, equals("parameter/"));
      expect(parameter.name, equals("Length"));
      expect(parameter.description, equals("Overall length"));
      expect(parameter.value, equals("12"));
      expect(parameter.units, equals("mm"));
      expect(parameter.valueString, equals("12 mm"));
      expect(parameter.is_checkbox, isFalse);
      expect(parameter.as_bool, isFalse);
      expect(parameter.modelType, equals("part"));
      expect(parameter.modelId, equals(3));

      final fields = parameter.formFields();
      expect(fields.keys, equals(["header", "data", "note"]));
      expect(fields["header"]?["label"], equals("Length"));
      expect(fields["header"]?["help_text"], equals("Overall length"));
      expect(fields["header"]?["read_only"], isTrue);
    });

    test("Checkbox", () async {
      final parameter = InvenTreeParameter.fromJson({
        "data": "True",
        "template_detail": {"name": "RoHS", "checkbox": true},
      });

      expect(parameter.is_checkbox, isTrue);
      expect(parameter.as_bool, isTrue);

      // No units, so the value is displayed alone
      expect(parameter.valueString, equals("True"));

      // No template detail
      final empty = InvenTreeParameter.fromJson({"data": "x"});
      expect(empty.is_checkbox, isFalse);
      expect(empty.as_bool, isFalse);
      expect(empty.valueString, equals("x"));
    });
  });

  group("BOM Item:", () {
    test("Accessors", () async {
      final item = InvenTreeBomItem.fromJson({
        "pk": 1,
        "part": 10,
        "sub_part": 20,
        "quantity": "2.5",
        "reference": "R1, R2",
        "part_detail": {"pk": 10, "name": "Assembly"},
        "sub_part_detail": {"pk": 20, "name": "Resistor"},
      });

      expect(item.URL, equals("bom/"));
      expect(item.defaultFilters()["sub_part_detail"], equals("true"));
      expect(item.partId, equals(10));
      expect(item.subPartId, equals(20));
      expect(item.quantity, equals(2.5));
      expect(item.reference, equals("R1, R2"));
      expect(item.part?.name, equals("Assembly"));
      expect(item.subPart?.name, equals("Resistor"));
      expect(item.createFromJson({"pk": 2}), isA<InvenTreeBomItem>());
    });

    test("Missing Detail", () async {
      final item = InvenTreeBomItem.fromJson({
        "sub_part_detail": null,
        "part_detail": "invalid",
      });

      expect(item.part, isNull);
      expect(item.subPart, isNull);
      expect(InvenTreeBomItem.fromJson({}).subPart, isNull);
      expect(InvenTreeBomItem.fromJson({}).subPartId, equals(-1));
    });
  });

  group("Note Entry:", () {
    test("Accessors", () async {
      final note = InvenTreeNoteEntry.fromJson({
        "pk": 2,
        "title": "Assembly notes",
        "content": "<p>Handle with care</p>",
        "updated": "2024-06-30",
        "model_type": "build",
        "model_id": 8,
      });

      expect(note.URL, equals("note/"));
      expect(note.title, equals("Assembly notes"));
      expect(note.content, equals("<p>Handle with care</p>"));
      expect(note.updated, equals(DateTime(2024, 6, 30)));
      expect(note.modelType, equals("build"));
      expect(note.modelId, equals(8));
      expect(note.createFromJson({"pk": 3}), isA<InvenTreeNoteEntry>());

      final empty = InvenTreeNoteEntry.fromJson({});
      expect(empty.content, equals(""));
      expect(empty.updated, isNull);
    });
  });
}
