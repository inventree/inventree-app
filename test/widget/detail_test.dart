/*
 * Widget tests for the "detail" screens, using the demo dataset.
 *
 * These tests require a running InvenTree server (see setup.dart)
 * with the demo dataset loaded. They do not modify any data.
 *
 * Each test finds a suitable object on the server, displays its detail
 * screen, waits for it to load, and then visits each tab.
 * On each tab, every link to another screen is opened (and closed again).
 * Any exception thrown while building the screens causes the test to fail.
 */

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:one_context/one_context.dart";

import "package:inventree/inventree/build.dart";
import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/purchase_order.dart";
import "package:inventree/inventree/sales_order.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/transfer_order.dart";
import "package:inventree/widget/build/build_detail.dart";
import "package:inventree/widget/build/build_item_detail.dart";
import "package:inventree/widget/build/build_line_detail.dart";
import "package:inventree/widget/company/company_detail.dart";
import "package:inventree/widget/company/manufacturer_part_detail.dart";
import "package:inventree/widget/company/supplier_part_detail.dart";
import "package:inventree/widget/order/extra_line_detail.dart";
import "package:inventree/widget/order/po_line_detail.dart";
import "package:inventree/widget/order/purchase_order_detail.dart";
import "package:inventree/widget/order/sales_order_detail.dart";
import "package:inventree/widget/order/so_line_detail.dart";
import "package:inventree/widget/order/so_shipment_detail.dart";
import "package:inventree/widget/order/transfer_order_detail.dart";
import "package:inventree/widget/order/transfer_order_line_detail.dart";
import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/part/part_detail.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/stock/stock_detail.dart";

import "../setup.dart";
import "harness.dart";

/*
 * Find the first object matching [filters], and load its full details
 */
Future<T> fetchFirst<T extends InvenTreeModel>(
  WidgetTester tester,
  T model, {
  Map<String, String> filters = const {},
}) async {
  final results = await settle(
    tester,
    model.list(filters: {...filters, "limit": "1"}),
  );

  expect(
    results,
    isNotEmpty,
    reason: "No ${T} matching ${filters} in the demo dataset",
  );

  final InvenTreeModel? instance = await settle(
    tester,
    model.get(results.first.pk),
  );

  expect(instance, isA<T>());

  return instance! as T;
}

/*
 * Display a detail [screen], and wait for it to load.
 * Then display each tab, and return to the first tab.
 */
Future<void> checkDetailScreen(WidgetTester tester, Widget screen) async {
  await pumpScreen(tester, screen);

  final state =
      tester.state(find.byWidget(screen)) as RefreshableState<StatefulWidget>;

  await waitUntil(tester, () => state.loaded, reason: "${screen} loaded");
  await idle(tester);

  expect(find.byType(AppBar), findsWidgets);

  final Finder tabs = find.descendant(
    of: find.byType(TabBar),
    matching: find.byType(Tab),
  );

  final int tabCount = tabs.evaluate().length;

  await followLinks(tester, screen);

  for (int idx = 1; idx < tabCount; idx++) {
    await tester.tap(tabs.at(idx));
    await idle(tester);
    await followLinks(tester, screen);
  }

  if (tabCount > 0) {
    await tester.tap(tabs.first);
    await idle(tester);
  }

  // Refresh the screen (as per a "pull down" gesture)
  state.refresh(state.context);

  await waitUntil(tester, () => state.loaded, reason: "${screen} reloaded");
  await idle(tester);
}

void main() {
  setupTestEnv();
  mockSharedPreferences();

  setUp(() {
    OneContext().key = GlobalKey<NavigatorState>();
    useNewTempDirectory();
  });

  group("Part Detail:", () {
    final Map<String, Map<String, String>> parts = {
      "Assembly": {"assembly": "true", "has_stock": "true"},
      "Component": {"component": "true", "purchaseable": "true"},
      "Template": {"is_template": "true"},
      "Trackable": {"trackable": "true"},
      "Salable": {"salable": "true"},
    };

    parts.forEach((name, filters) {
      testWidgets(name, (tester) async {
        await withServer(tester, displayAll: true, () async {
          final part = await fetchFirst(
            tester,
            InvenTreePart(),
            filters: filters,
          );

          await checkDetailScreen(tester, PartDetailWidget(part));
        });
      });
    });
  });

  group("Part Category:", () {
    testWidgets("Top Level", (tester) async {
      await withServer(tester, displayAll: true, () async {
        await checkDetailScreen(tester, CategoryDisplayWidget(null));
      });
    });

    testWidgets("Category", (tester) async {
      await withServer(tester, displayAll: true, () async {
        final category = await fetchFirst(
          tester,
          InvenTreePartCategory(),
          filters: {"parent": "1"},
        );

        await checkDetailScreen(tester, CategoryDisplayWidget(category));
      });
    });
  });

  group("Stock Detail:", () {
    final Map<String, Map<String, String>> items = {
      "Serialized": {"serialized": "true"},
      "Batch": {"serialized": "false", "has_batch": "true"},
      "Testable": {
        "part_detail": "true",
        "serialized": "true",
        "has_tests": "true",
      },
    };

    items.forEach((name, filters) {
      testWidgets(name, (tester) async {
        await withServer(tester, displayAll: true, () async {
          final item = await fetchFirst(
            tester,
            InvenTreeStockItem(),
            filters: filters,
          );

          await checkDetailScreen(tester, StockDetailWidget(item));
        });
      });
    });
  });

  group("Stock Location:", () {
    testWidgets("Top Level", (tester) async {
      await withServer(tester, displayAll: true, () async {
        await checkDetailScreen(tester, LocationDisplayWidget(null));
      });
    });

    testWidgets("Location", (tester) async {
      await withServer(tester, displayAll: true, () async {
        final location = await fetchFirst(
          tester,
          InvenTreeStockLocation(),
          filters: {"parent": "1"},
        );

        await checkDetailScreen(tester, LocationDisplayWidget(location));
      });
    });
  });

  /*
   * Test the detail screen for the first [model] matching [filters]
   */
  void detailTest<T extends InvenTreeModel>(
    String name,
    T model,
    Widget Function(T instance) screen, {
    Map<String, String> filters = const {},
  }) {
    testWidgets(name, (tester) async {
      await withServer(tester, displayAll: true, () async {
        final T instance = await fetchFirst(tester, model, filters: filters);

        await checkDetailScreen(tester, screen(instance));
      });
    });
  }

  group("Purchase Order:", () {
    detailTest(
      "Open",
      InvenTreePurchaseOrder(),
      (order) => PurchaseOrderDetailWidget(order),
      filters: {"outstanding": "true"},
    );

    detailTest(
      "Closed",
      InvenTreePurchaseOrder(),
      (order) => PurchaseOrderDetailWidget(order),
      filters: {"outstanding": "false"},
    );

    detailTest(
      "Line Item",
      InvenTreePOLineItem(),
      (line) => POLineDetailWidget(line),
    );

    detailTest(
      "Extra Line Item",
      InvenTreePOExtraLineItem(),
      (line) => ExtraLineDetailWidget(line),
    );
  });

  group("Sales Order:", () {
    detailTest(
      "Open",
      InvenTreeSalesOrder(),
      (order) => SalesOrderDetailWidget(order),
      filters: {"outstanding": "true"},
    );

    detailTest(
      "Closed",
      InvenTreeSalesOrder(),
      (order) => SalesOrderDetailWidget(order),
      filters: {"outstanding": "false"},
    );

    detailTest(
      "Line Item",
      InvenTreeSOLineItem(),
      (line) => SoLineDetailWidget(line),
    );

    detailTest(
      "Extra Line Item",
      InvenTreeSOExtraLineItem(),
      (line) => ExtraLineDetailWidget(line),
    );

    detailTest(
      "Shipment",
      InvenTreeSalesOrderShipment(),
      (shipment) => SOShipmentDetailWidget(shipment),
    );
  });

  group("Transfer Order:", () {
    detailTest(
      "Order",
      InvenTreeTransferOrder(),
      (order) => TransferOrderDetailWidget(order),
    );

    detailTest(
      "Line Item",
      InvenTreeTransferOrderLineItem(),
      (line) => TransferOrderLineDetailWidget(line),
    );
  });

  group("Build Order:", () {
    detailTest(
      "Open",
      InvenTreeBuildOrder(),
      (build) => BuildOrderDetailWidget(build),
      filters: {"outstanding": "true"},
    );

    detailTest(
      "Closed",
      InvenTreeBuildOrder(),
      (build) => BuildOrderDetailWidget(build),
      filters: {"outstanding": "false"},
    );

    detailTest(
      "Line Item",
      InvenTreeBuildLine(),
      (line) => BuildLineDetailWidget(line),
    );

    detailTest(
      "Allocated Item",
      InvenTreeBuildItem(),
      (item) => BuildItemDetailWidget(item),
    );
  });

  group("Company:", () {
    final Map<String, Map<String, String>> companies = {
      "Supplier": {"is_supplier": "true"},
      "Manufacturer": {"is_manufacturer": "true"},
      "Customer": {"is_customer": "true"},
    };

    companies.forEach((name, filters) {
      detailTest(
        name,
        InvenTreeCompany(),
        (company) => CompanyDetailWidget(company),
        filters: filters,
      );
    });

    detailTest(
      "Supplier Part",
      InvenTreeSupplierPart(),
      (part) => SupplierPartDetailWidget(part),
    );

    detailTest(
      "Manufacturer Part",
      InvenTreeManufacturerPart(),
      (part) => ManufacturerPartDetailWidget(part),
    );
  });
}
