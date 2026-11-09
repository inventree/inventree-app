/*
 * Unit tests for order and company model classes constructed from JSON data
 *
 * Status code data is provided directly, rather than loaded from the server
 */

import "package:flutter_test/flutter_test.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/status_codes.dart";
import "package:inventree/inventree/transfer_order.dart";

// Construct status code data in the format provided by the server
Map<String, dynamic> statusData(Map<String, int> codes) {
  return codes.map(
    (name, key) =>
        MapEntry(name, {"key": key, "name": name, "label": name.toLowerCase()}),
  );
}

// Add a user-defined custom state to the provided status codes,
// in the format provided by the server.
// Custom states have their own key and name, and map to a logical key
void addCustomState(InvenTreeStatusCode codes, int key, int logicalKey) {
  codes.data["CUSTOM_${key}"] = {
    "key": key,
    "logical_key": logicalKey,
    "name": "CUSTOM_${key}",
    "label": "Custom ${key}",
    "color": "info",
    "custom": true,
  };
}

void main() {
  setUp(() {
    InvenTreeAPI().BuildOrderStatus.data = statusData({
      "PENDING": 10,
      "PRODUCTION": 20,
      "CANCELLED": 30,
      "COMPLETE": 40,
      "ON_HOLD": 25,
    });

    InvenTreeAPI().PurchaseOrderStatus.data = statusData({
      "PENDING": 10,
      "PLACED": 20,
      "ON_HOLD": 25,
      "COMPLETE": 30,
      "CANCELLED": 40,
      "LOST": 50,
      "RETURNED": 60,
    });

    InvenTreeAPI().SalesOrderStatus.data = statusData({
      "PENDING": 10,
      "IN_PROGRESS": 15,
      "SHIPPED": 20,
      "ON_HOLD": 25,
      "COMPLETE": 30,
      "CANCELLED": 40,
    });

    InvenTreeAPI().TransferOrderStatus.data = statusData({
      "PENDING": 10,
      "ISSUED": 20,
      "ON_HOLD": 25,
      "COMPLETE": 30,
      "CANCELLED": 40,
    });
  });

  tearDown(() {
    InvenTreeAPI().clearStatusCodeData();
    InvenTreeAPI().serverInfo = {};
  });

  group("Build Order:", () {
    test("Quantities", () async {
      var build = InvenTreeBuildOrder.fromJson({
        "quantity": 10,
        "completed": 4,
        "item_count": 3,
        "allocated_line_count": 3,
        "output_count": 2,
      });

      expect(build.progressPercent, equals(40));
      expect(build.remaining, equals(6));
      expect(build.lineItemCount, equals(3));
      expect(build.areAllLinesAllocated, isTrue);
      expect(build.outputCount, equals(2));

      // Progress is clamped
      build = InvenTreeBuildOrder.fromJson({"quantity": 10, "completed": 15});
      expect(build.progressPercent, equals(100));

      build = InvenTreeBuildOrder.fromJson({"quantity": 0, "completed": 1});
      expect(build.progressPercent, equals(0));

      // No line items
      expect(InvenTreeBuildOrder.fromJson({}).areAllLinesAllocated, isFalse);
    });

    test("Details", () async {
      var build = InvenTreeBuildOrder.fromJson({
        "parent": 3,
        "part_detail": {"name": "Assembly"},
        "destination_detail": {"name": "Store"},
      });

      expect(build.isParentBuild, isTrue);
      expect(build.parentBuildId, equals(3));
      expect(build.partDetail?.name, equals("Assembly"));
      expect(build.destinationName, equals("Store"));

      build = InvenTreeBuildOrder.fromJson({});
      expect(build.isParentBuild, isFalse);
      expect(build.partDetail, isNull);
    });

    test("Status", () async {
      InvenTreeBuildOrder build(int status) =>
          InvenTreeBuildOrder.fromJson({"status": status, "output_count": 1});

      final pending = build(10);
      expect(pending.isWaitingForBuild, isTrue);
      expect(pending.canIssue, isTrue);
      expect(pending.canHold, isTrue);
      expect(pending.canCancel, isTrue);
      expect(pending.canCompleteOrder, isFalse);

      final production = build(20);
      expect(production.isInProgress, isTrue);
      expect(production.canIssue, isFalse);
      expect(production.canHold, isTrue);
      expect(production.canCompleteOrder, isTrue);

      // Cannot complete without any outputs
      expect(
        InvenTreeBuildOrder.fromJson({"status": 20}).canCompleteOrder,
        isFalse,
      );

      final onHold = build(25);
      expect(onHold.isOnHold, isTrue);
      expect(onHold.canIssue, isTrue);
      expect(onHold.canHold, isFalse);

      final complete = build(40);
      expect(complete.isComplete, isTrue);
      expect(complete.canCancel, isFalse);

      final cancelled = build(30);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.canCancel, isFalse);
      expect(cancelled.canIssue, isFalse);
    });

    // Regression: a custom state must not hide the actions for its logical state
    test("Custom Status", () async {
      addCustomState(InvenTreeAPI().BuildOrderStatus, 101, 20);

      final build = InvenTreeBuildOrder.fromJson({
        "status": 20,
        "status_custom_key": 101,
        "output_count": 1,
      });

      expect(build.status, equals(101));
      expect(build.logicalStatus, equals(20));
      expect(build.isInProgress, isTrue);
      expect(build.canHold, isTrue);
      expect(build.canCancel, isTrue);
      expect(build.canCompleteOrder, isTrue);

      // Display uses the custom state
      expect(InvenTreeAPI().BuildOrderStatus.label(build.status), "Custom 101");
    });

    test("Build Line", () async {
      var line = InvenTreeBuildLine.fromJson({
        "quantity": 10,
        "allocated": 5,
        "bom_item_detail": {"reference": "R1"},
      });

      expect(line.isFullyAllocated, isFalse);
      expect(line.isOverallocated, isFalse);
      expect(line.progressPercent, equals(50));
      expect(line.bomReference, equals("R1"));

      // Allow for floating point error
      line = InvenTreeBuildLine.fromJson({
        "quantity": 0.3,
        "allocated": 0.1 + 0.2 - 0.00001,
      });
      expect(line.isFullyAllocated, isTrue);

      line = InvenTreeBuildLine.fromJson({"quantity": 2, "allocated": 3});
      expect(line.isOverallocated, isTrue);
      expect(line.progressPercent, equals(100));

      line = InvenTreeBuildLine.fromJson({"quantity": 0});
      expect(line.progressPercent, equals(0));
    });

    test("Build Item", () async {
      var item = InvenTreeBuildItem.fromJson({
        "quantity": 2,
        "stock_item_detail": {"quantity": 5, "serial": ""},
        "part_detail": {"name": "Resistor"},
      });

      expect(item.quantity, equals(2));
      expect(item.stockItem?.quantity, equals(5));
      expect(item.partName, equals("Resistor"));

      expect(InvenTreeBuildItem.fromJson({}).stockItem, isNull);
    });
  });

  group("Purchase Order:", () {
    test("Status", () async {
      InvenTreePurchaseOrder order(int status) =>
          InvenTreePurchaseOrder.fromJson({"status": status});

      expect(order(10).isOpen, isTrue);
      expect(order(10).isPending, isTrue);
      expect(order(10).isPlaced, isFalse);

      expect(order(20).isOpen, isTrue);
      expect(order(20).isPlaced, isTrue);
      expect(order(20).isPending, isFalse);

      expect(order(25).isPending, isTrue);

      expect(order(30).isOpen, isFalse);
      expect(order(30).isFailed, isFalse);

      for (final status in [40, 50, 60]) {
        expect(order(status).isFailed, isTrue);
        expect(order(status).isOpen, isFalse);
      }
    });

    // Regression: a custom state must not hide the actions for its logical state
    test("Custom Status", () async {
      addCustomState(InvenTreeAPI().PurchaseOrderStatus, 101, 10);
      addCustomState(InvenTreeAPI().PurchaseOrderStatus, 102, 20);

      final pending = InvenTreePurchaseOrder.fromJson({
        "status": 10,
        "status_custom_key": 101,
      });

      expect(pending.isOpen, isTrue);
      expect(pending.isPending, isTrue);

      final placed = InvenTreePurchaseOrder.fromJson({
        "status": 20,
        "status_custom_key": 102,
      });

      expect(placed.isOpen, isTrue);
      expect(placed.isPlaced, isTrue);
      expect(placed.isPending, isFalse);
    });

    test("Supplier", () async {
      var order = InvenTreePurchaseOrder.fromJson({
        "supplier": 2,
        "supplier_detail": {"name": "ACME"},
        "supplier_reference": "REF-1",
      });

      expect(order.supplierId, equals(2));
      expect(order.supplier?.name, equals("ACME"));
      expect(order.supplierReference, equals("REF-1"));

      expect(InvenTreePurchaseOrder.fromJson({}).supplier, isNull);
    });

    test("Line Item", () async {
      var line = InvenTreePOLineItem.fromJson({
        "quantity": 8,
        "received": 2,
        "purchase_price": "1.5",
        "supplier_part_detail": {"SKU": "SKU-1"},
        "order_detail": {"reference": "PO-1"},
      });

      expect(line.isComplete, isFalse);
      expect(line.progressRatio, equals(0.25));
      expect(line.progressString, equals("2 / 8"));
      expect(line.outstanding, equals(6));
      expect(line.SKU, equals("SKU-1"));
      expect(line.purchasePrice, equals(1.5));
      expect(line.supplierPart?.SKU, equals("SKU-1"));
      expect(line.purchaseOrder?.reference, equals("PO-1"));

      line = InvenTreePOLineItem.fromJson({"quantity": 8, "received": 8});
      expect(line.isComplete, isTrue);
      expect(line.supplierPart, isNull);
      expect(line.purchaseOrder, isNull);

      line = InvenTreePOLineItem.fromJson({"quantity": 0});
      expect(line.progressRatio, equals(0));
    });
  });

  group("Sales Order:", () {
    test("Status", () async {
      InvenTreeSalesOrder order(int status) =>
          InvenTreeSalesOrder.fromJson({"status": status});

      expect(order(10).isOpen, isTrue);
      expect(order(10).isPending, isTrue);

      expect(order(15).isOpen, isTrue);
      expect(order(15).isInProgress, isTrue);
      expect(order(15).isPending, isFalse);

      expect(order(25).isPending, isTrue);

      expect(order(20).isComplete, isTrue);
      expect(order(20).isOpen, isFalse);

      expect(order(40).isOpen, isFalse);
    });

    // Regression: a custom state must not hide the actions for its logical state
    test("Custom Status", () async {
      addCustomState(InvenTreeAPI().SalesOrderStatus, 101, 15);

      final order = InvenTreeSalesOrder.fromJson({
        "status": 15,
        "status_custom_key": 101,
      });

      expect(order.isOpen, isTrue);
      expect(order.isInProgress, isTrue);
      expect(order.isComplete, isFalse);
    });

    test("Customer", () async {
      var order = InvenTreeSalesOrder.fromJson({
        "customer": 4,
        "customer_detail": {"name": "Customer"},
        "customer_reference": "CUST-1",
      });

      expect(order.customerId, equals(4));
      expect(order.customer?.name, equals("Customer"));
      expect(order.customerReference, equals("CUST-1"));

      expect(InvenTreeSalesOrder.fromJson({}).customer, isNull);
    });

    test("Line Item", () async {
      var line = InvenTreeSOLineItem.fromJson({
        "quantity": 10,
        "allocated": 4,
        "shipped": 5,
        "available_stock": 7,
        "available_variant_stock": 3,
      });

      expect(line.isAllocated, isFalse);
      expect(line.allocatedRatio, equals(0.4));
      expect(line.unallocatedQuantity, equals(6));
      expect(line.allocatedString, equals("4 / 10"));
      expect(line.progressRatio, equals(0.5));
      expect(line.progressString, equals("5 / 10"));
      expect(line.outstanding, equals(5));
      expect(line.isComplete, isFalse);
      expect(line.availableStock, equals(7));
      expect(line.available, equals(10));

      // Overallocated
      line = InvenTreeSOLineItem.fromJson({
        "quantity": 2,
        "allocated": 5,
        "shipped": 2,
      });

      expect(line.isAllocated, isTrue);
      expect(line.unallocatedQuantity, equals(0));
      expect(line.isComplete, isTrue);

      line = InvenTreeSOLineItem.fromJson({"quantity": 0});
      expect(line.allocatedRatio, equals(0));
      expect(line.progressRatio, equals(0));

      expect(
        line.allocateFormFields()["stock_item"]?["parent"],
        equals("items"),
      );
    });

    test("Shipment", () async {
      var shipment = InvenTreeSalesOrderShipment.fromJson({
        "pk": 3,
        "reference": "SHIP-1",
        "checked_by": 1,
        "shipment_date": "2025-01-01",
        "delivery_date": "",
        "order_detail": {"reference": "SO-1"},
      });

      expect(shipment.SHIP_SHIPMENT_URL, equals("order/so/shipment/3/ship/"));
      expect(shipment.reference, equals("SHIP-1"));
      expect(shipment.isChecked, isTrue);
      expect(shipment.isShipped, isTrue);
      expect(shipment.isDelivered, isFalse);
      expect(shipment.order?.reference, equals("SO-1"));

      shipment = InvenTreeSalesOrderShipment.fromJson({});
      expect(shipment.isChecked, isFalse);
      expect(shipment.isShipped, isFalse);
      expect(shipment.order, isNull);
    });

    test("Allocation", () async {
      var allocation = InvenTreeSalesOrderAllocation.fromJson({
        "shipment": 2,
        "order_detail": {"reference": "SO-1"},
        "item_detail": {"serial": "123"},
        "part_detail": {"name": "Widget"},
        "shipment_detail": {"reference": "SHIP-1"},
        "location_detail": {"name": "Shelf"},
      });

      expect(allocation.hasShipment, isTrue);
      expect(allocation.order?.reference, equals("SO-1"));
      expect(allocation.stockItem?.serialNumber, equals("123"));
      expect(allocation.part?.name, equals("Widget"));
      expect(allocation.shipment?.reference, equals("SHIP-1"));
      expect(allocation.location?.name, equals("Shelf"));

      allocation = InvenTreeSalesOrderAllocation.fromJson({});
      expect(allocation.hasShipment, isFalse);
      expect(allocation.order, isNull);
      expect(allocation.stockItem, isNull);
      expect(allocation.part, isNull);
      expect(allocation.shipment, isNull);
      expect(allocation.location, isNull);
    });
  });

  group("Transfer Order:", () {
    test("Status Codes", () async {
      final codes = InvenTreeAPI().TransferOrderStatus;

      // Status codes are loaded from the generic server endpoint
      expect(codes.URL, equals("generic/status/TransferOrderStatus/"));

      expect(codes.name(10), equals("PENDING"));
      expect(codes.name(99), equals(""));
      expect(codes.isNameIn(30, ["COMPLETE"]), isTrue);
      expect(codes.isNameIn(99, ["COMPLETE"]), isFalse);

      // Labels are provided by the server
      expect(codes.label(20), equals("issued"));
      expect(codes.label(99), equals("99"));

      // Status data is cleared along with other status codes
      InvenTreeAPI().clearStatusCodeData();
      expect(codes.data, isEmpty);
    });

    test("Status", () async {
      InvenTreeTransferOrder order(int status) =>
          InvenTreeTransferOrder.fromJson({"status": status});

      final pending = order(10);
      expect(pending.isOpen, isTrue);
      expect(pending.canIssue, isTrue);
      expect(pending.canHold, isTrue);
      expect(pending.canCompleteOrder, isFalse);
      expect(pending.canCancel, isTrue);

      final issued = order(20);
      expect(issued.canIssue, isFalse);
      expect(issued.canHold, isTrue);
      expect(issued.canCompleteOrder, isTrue);

      final onHold = order(25);
      expect(onHold.canIssue, isTrue);
      expect(onHold.canHold, isFalse);
      expect(onHold.canCompleteOrder, isTrue);

      for (final status in [30, 40]) {
        expect(order(status).isOpen, isFalse);
        expect(order(status).canCancel, isFalse);
        expect(order(status).canCompleteOrder, isFalse);
      }
    });

    // Regression: a custom state must not hide the actions for its logical state
    test("Custom Status", () async {
      addCustomState(InvenTreeAPI().TransferOrderStatus, 101, 20);

      final order = InvenTreeTransferOrder.fromJson({
        "status": 20,
        "status_custom_key": 101,
      });

      expect(order.status, equals(101));
      expect(order.isIssued, isTrue);
      expect(order.isOpen, isTrue);
      expect(order.canHold, isTrue);
      expect(order.canCompleteOrder, isTrue);
      expect(order.canCancel, isTrue);

      // Display uses the custom state
      expect(
        InvenTreeAPI().TransferOrderStatus.label(order.status),
        equals("Custom 101"),
      );
    });

    test("Locations", () async {
      var order = InvenTreeTransferOrder.fromJson({
        "take_from": 2,
        "destination": 3,
        "consume": true,
      });

      expect(order.sourceLocationId, equals(2));
      expect(order.destinationId, equals(3));
      expect(order.consume, isTrue);

      order = InvenTreeTransferOrder.fromJson({"take_from": null});
      expect(order.sourceLocationId, isNull);
      expect(order.destinationId, isNull);
    });

    test("Line Item", () async {
      var line = InvenTreeTransferOrderLineItem.fromJson({
        "quantity": 4,
        "allocated": 4,
        "transferred": 1,
        "order_detail": {"reference": "TO-1"},
      });

      expect(line.isComplete, isFalse);
      expect(line.outstanding, equals(3));
      expect(line.progressRatio, equals(0.25));
      expect(line.progressString, equals("1 / 4"));
      expect(line.transferOrder?.reference, equals("TO-1"));

      line = InvenTreeTransferOrderLineItem.fromJson({"quantity": 0});
      expect(line.isComplete, isTrue);
      expect(line.progressRatio, equals(0));
      expect(line.transferOrder, isNull);
    });

    test("Allocation", () async {
      var allocation = InvenTreeTransferOrderAllocation.fromJson({
        "quantity": 2,
        "order_detail": {"reference": "TO-1"},
        "item_detail": {"serial": "123"},
        "part_detail": {"name": "Widget"},
        "location_detail": {"name": "Shelf"},
      });

      expect(allocation.quantity, equals(2));
      expect(allocation.order?.reference, equals("TO-1"));
      expect(allocation.stockItem?.serialNumber, equals("123"));
      expect(allocation.part?.name, equals("Widget"));
      expect(allocation.location?.name, equals("Shelf"));

      allocation = InvenTreeTransferOrderAllocation.fromJson({});
      expect(allocation.order, isNull);
      expect(allocation.stockItem, isNull);
      expect(allocation.part, isNull);
      expect(allocation.location, isNull);
    });
  });

  group("Company:", () {
    test("Company", () async {
      var company = InvenTreeCompany.fromJson({});

      expect(company.image, equals(InvenTreeAPI.staticImage));
      expect(company.thumbnail, equals(InvenTreeAPI.staticThumb));
      expect(company.active, isTrue);
      expect(company.isSupplier, isFalse);

      company = InvenTreeCompany.fromJson({
        "image": "/media/c.png",
        "is_supplier": true,
        "is_customer": true,
        "active": false,
      });

      expect(company.image, equals("/media/c.png"));
      expect(company.thumbnail, equals("/media/c.png"));
      expect(company.isSupplier, isTrue);
      expect(company.isCustomer, isTrue);
      expect(company.isManufacturer, isFalse);
      expect(company.active, isFalse);

      company = InvenTreeCompany.fromJson({"thumbnail": "/media/c.thumb.png"});
      expect(company.image, equals("/media/c.thumb.png"));
    });

    test("Company Form Fields", () async {
      expect(InvenTreeCompany().formFields().containsKey("active"), isFalse);

      InvenTreeAPI().serverInfo = {"apiVersion": 189};
      expect(InvenTreeCompany().formFields().containsKey("active"), isTrue);
    });

    test("Supplier Part", () async {
      var sp = InvenTreeSupplierPart.fromJson({
        "SKU": "SKU-1",
        "pack_size": "10",
        "pack_quantity": "1 reel",
        "manufacturer_detail": {"pk": 5, "name": "MFG", "thumbnail": "/m.png"},
        "supplier_detail": {"name": "ACME", "image": "/s.png"},
        "manufacturer_part_detail": {"MPN": "MPN-1"},
        "part_detail": {"name": "Widget", "thumbnail": "/p.png"},
      });

      expect(sp.SKU, equals("SKU-1"));
      expect(sp.manufacturerId, equals(5));
      expect(sp.manufacturerName, equals("MFG"));
      expect(sp.manufacturerImage, equals("/m.png"));
      expect(sp.supplierName, equals("ACME"));
      expect(sp.supplierImage, equals("/s.png"));
      expect(sp.MPN, equals("MPN-1"));
      expect(sp.partName, equals("Widget"));
      expect(sp.partImage, equals("/p.png"));
      expect(sp.active, isTrue);
      expect(sp.primary, isFalse);

      // Older API versions use "pack_size"
      expect(sp.pack_quantity, equals("10"));
      expect(sp.formFields().containsKey("pack_size"), isTrue);
      expect(sp.formFields().containsKey("primary"), isFalse);

      InvenTreeAPI().serverInfo = {"apiVersion": 456};
      expect(sp.pack_quantity, equals("1 reel"));
      expect(sp.formFields().containsKey("pack_quantity"), isTrue);
      expect(sp.formFields().containsKey("primary"), isTrue);

      // Missing images
      sp = InvenTreeSupplierPart.fromJson({});
      expect(sp.manufacturerImage, equals(InvenTreeAPI.staticThumb));
      expect(sp.supplierImage, equals(InvenTreeAPI.staticThumb));
      expect(sp.partImage, equals(InvenTreeAPI.staticThumb));
    });

    test("Manufacturer Part", () async {
      var mp = InvenTreeManufacturerPart.fromJson({
        "MPN": "MPN-1",
        "manufacturer": 5,
        "manufacturer_detail": {
          "name": "MFG",
          "description": "Manufacturer",
          "image": "/m.png",
        },
        "part_detail": {"name": "Widget", "IPN": "W-1"},
      });

      expect(mp.MPN, equals("MPN-1"));
      expect(mp.manufacturerId, equals(5));
      expect(mp.manufacturerName, equals("MFG"));
      expect(mp.manufacturerDescription, equals("Manufacturer"));
      expect(mp.manufacturerImage, equals("/m.png"));
      expect(mp.partName, equals("Widget"));
      expect(mp.partIPN, equals("W-1"));
      expect(mp.partImage, equals(InvenTreeAPI.staticThumb));

      mp = InvenTreeManufacturerPart.fromJson({});
      expect(mp.manufacturerImage, equals(InvenTreeAPI.staticThumb));
    });
  });
}
