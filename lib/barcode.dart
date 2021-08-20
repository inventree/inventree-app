import 'package:dropdown_search/dropdown_search.dart';
import 'package:inventree/app_settings.dart';
import 'package:inventree/inventree/order.dart';
import 'package:inventree/inventree/sentry.dart';
import 'package:inventree/widget/dialogs.dart';
import 'package:inventree/widget/fields.dart';
import 'package:inventree/widget/snacks.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:one_context/one_context.dart';

import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:inventree/inventree/stock.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/l10.dart';

import 'package:inventree/api.dart';

import 'package:inventree/widget/location_display.dart';
import 'package:inventree/widget/part_detail.dart';
import 'package:inventree/widget/stock_detail.dart';

import 'dart:io';

import 'inventree/company.dart';
import 'inventree/model.dart';

class BarcodeHandler {
  /*
   * Class which "handles" a barcode, by communicating with the InvenTree server,
   * and handling match / unknown / error cases.
   *
   * Override functionality of this class to perform custom actions,
   * based on the response returned from the InvenTree server
   */

  String getOverlayText(BuildContext context) => "Barcode Overlay";

  BarcodeHandler();

  void successTone() async {
    final bool en = await InvenTreeSettingsManager()
        .getValue("barcodeSounds", true) as bool;

    if (en) {
      final player = AudioCache();
      player.play("sounds/barcode_scan.mp3");
    }
  }

  void failureTone() async {
    final bool en = await InvenTreeSettingsManager()
        .getValue("barcodeSounds", true) as bool;

    if (en) {
      final player = AudioCache();
      player.play("sounds/barcode_error.mp3");
    }
  }

  Future<void> onBarcodeMatched(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    // Called when the server "matches" a barcode
    // Override this function

    // Resume scanning.
    controller?.resumeCamera();
  }

  Future<void> onBarcodeUnknown(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    // Called when the server does not know about a barcode
    // Override this function
    failureTone();

    showSnackIcon(L10().barcodeNoMatch,
        success: false, icon: FontAwesomeIcons.qrcode);
    // Resume scanning by default.
    controller?.resumeCamera();
  }

  Future<void> onBarcodeUnhandled(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    failureTone();

    // Called when the server returns an unhandled response
    showServerError(L10().responseUnknown, data.toString());
    // Resume scanning.
    controller?.resumeCamera();
  }

  Future<void> processBarcode(
      BuildContext context, QRViewController? controller, String barcode,
      {String url = "barcode/"}) async {
    // Pause scanning while handling the barcode.
    controller?.pauseCamera();

    print("Scanned barcode data: ${barcode}");

    var response = await InvenTreeAPI().post(url,
        body: {
          "barcode": barcode,
        },
        expectedStatusCode: 200);

    // Handle strange response from the server
    if (!response.isValid() ||
        response.data == null ||
        !(response.data is Map)) {
      // We want to know about this one!
      await sentryReportMessage(
          "BarcodeHandler.processBarcode returned strange value",
          context: {
            "data": response.data?.toString() ?? "null",
            "barcode": barcode,
            "url": url,
            "statusCode": response.statusCode.toString(),
            "valid": response.isValid().toString(),
            "error": response.error,
            "errorDetail": response.errorDetail,
          });
      // Resume scanning.
      controller?.resumeCamera();
    } else if (response.data.containsKey('error')) {
      onBarcodeUnknown(context, controller, response.data);
    } else if (response.data.containsKey('success')) {
      onBarcodeMatched(context, controller, response.data);
    } else {
      onBarcodeUnhandled(context, controller, response.data);
    }
  }
}

Widget _renderPurchaseOrder(InvenTreePO? order, bool selected, bool extended) {
  if (order == null) {
    return Text(
      "Select Purchase Order",
      style: TextStyle(fontStyle: FontStyle.italic),
    );
  }

  return ListTile(
    title: Text("${order.creationDate} - ${order.description}",
        style: TextStyle(
            fontWeight:
                selected && extended ? FontWeight.bold : FontWeight.normal)),
    // subtitle: extended
    //     ? Text(
    //         part.description,
    //         style: TextStyle(
    //             fontWeight: selected ? FontWeight.bold : FontWeight.normal),
    //       )
    //     : null,
    // leading: extended
    //     ? InvenTreeAPI().getImage(part.thumbnail, width: 40, height: 40)
    //     : null,
  );
}

Widget _buildSupplierPart(BuildContext context, InvenTreeSupplierPart? part,
    bool selected, bool extended) {
  if (part == null) {
    return Text(
      "Select Part",
      style: TextStyle(fontStyle: FontStyle.italic),
    );
  }

  return ListTile(
    title: Text(part.part.fullname,
        style: TextStyle(
            fontWeight:
                selected && extended ? FontWeight.bold : FontWeight.normal)),
    subtitle: Text("${part.description}"),
    leading: InvenTreeAPI().getImage(
      part.part.thumbnail,
      width: 40,
      height: 40,
    ),
  );
}

Widget _buildLineItem(BuildContext context, InvenTreePOLineItem item,
    InvenTreeSupplierPart part) {
  return ListTile(
    title: Text(part.part.IPN),
    subtitle: Text("${part.part.name}"),
    trailing: Text("${item.received}"),
    leading: InvenTreeAPI().getImage(
      part.part.thumbnail,
      width: 40,
      height: 40,
    ),
  );
}

final receiveLineItemKey = GlobalKey<FormState>();

Future<T?> _receiveLineItem<T>(
    BuildContext context,
    QRViewController? controller,
    InvenTreePOLineItem item,
    InvenTreeSupplierPart part,
    String barcodeHash) async {
  final quantityController = TextEditingController();

  final quantity = QuantityField(
    label: "Received",
    max: item.quantity - item.received,
    controller: quantityController,
  );

  InvenTreeModel? existingDestination = null;
  if (item.destination >= 0) {
    existingDestination = await InvenTreeStockLocation().get(item.destination);
  }

  int? location_pk =
      existingDestination != null ? existingDestination.pk : null;

  final fields = <Widget>[
    _buildLineItem(context, item, part),
    Text("Waiting to be received: ${item.quantity - item.received}"),
    ListTile(title: quantity),
    ListTile(
        title: DropdownSearch<dynamic>(
      mode: Mode.BOTTOM_SHEET,
      showSelectedItem: false,
      autoFocusSearchBox: true,
      selectedItem:
          existingDestination != null ? existingDestination.jsondata : null,
      errorBuilder: (context, entry, exception) {
        print("entry: $entry");
        print(exception.toString());

        return Text(exception.toString(),
            style: TextStyle(
              fontSize: 10,
            ));
      },
      onFind: (String filter) async {
        Map<String, String> _filters = {
          "search": filter,
          "offset": "0",
          "limit": "25"
        };

        final List<InvenTreeModel> results =
            await InvenTreeStockLocation().list(filters: _filters);

        List<dynamic> items = [];

        for (InvenTreeModel loc in results) {
          if (loc is InvenTreeStockLocation) {
            items.add(loc.jsondata);
          }
        }

        return items;
      },
      label: L10().stockLocation,
      hint: L10().searchLocation,
      onChanged: (dynamic location) {
        if (location == null) {
          location_pk = null;
        } else {
          location_pk = location['pk'];
        }
      },
      itemAsString: (dynamic location) {
        return location['pathstring'];
      },
      isFilteredOnline: true,
      showSearchBox: true,
    ))
  ];

  return showFormDialog<T>(
    "Received amount",
    key: receiveLineItemKey,
    callback: () {
      int amountReceived = int.parse(quantityController.value.text);

      print("${item.received + amountReceived}");

      item.update(values: {
        "received": "${item.received + amountReceived}",
        "purchase_price": item.purchasePrice.toString()
      }).then((updated) async {
        if (updated) {
          var data = {
            "part": part.part.pk,
            "supplier_part": part.pk,
            "quantity": amountReceived,
            "purchase_order": item.order,
            "uid": barcodeHash,
            "purchase_price": item.purchasePrice
          };

          if (location_pk != null) {
            data.putIfAbsent("location", () => location_pk!);
          }

          print(data);

          var stockItem =
              await InvenTreeStockItem().create(data) as InvenTreeStockItem?;

          if (stockItem != null) {
            showSnackIcon("Received ${amountReceived}x ${part.part.name}",
                success: true, icon: FontAwesomeIcons.boxes, onAction: () {
              // Redirect to the stock page.
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => StockDetailWidget(stockItem)));
            });
          } else {
            // Called when the server returns an unhandled response
            showServerError(L10().responseUnknown,
                "Unable to create stock for received item ${part.part.name}");
          }
        } else {
          // Called when the server returns an unhandled response
          showServerError(L10().responseUnknown, "Unable to update POLineItem");
        }
      });
    },
    fields: fields,
  );
}

void _onReceiveLineItem(
    BuildContext context, QRViewController? controller, String barcodeHash) {
  // Close the scanner.
  //Navigator.of(context).pop();
  InvenTreeSupplierPart? selectedSupplierPart = null;
  InvenTreePOLineItem? selectedLineItem = null;

  Map<int, List<InvenTreePOLineItem>> supplierPartIdToLineItemMap = {};
  Map<int, InvenTreePO> orderMap = {};

  var partSearch = DropdownSearch<InvenTreeSupplierPart>(
      mode: Mode.BOTTOM_SHEET,
      showSelectedItem: true,
      onFind: (String filter) async {
        // Oh my god this became a monster...
        return InvenTreeAPI().get("/order/po/.*/", params: {}).then((response) {
          // Retrieve PurchaseOrders:
          // PurchaseOrders constructed from JSON
          final pos = (response.data as List).map((po) {
            return InvenTreePO.fromJson(po);
          }).toList();
          // Keep only PurchaseOrders that are waiting to be received.
          pos.retainWhere((po) => po.status == PO_STATUS_PLACED);
          // Cache the PurchaseOrder.
          pos.forEach((order) => orderMap.putIfAbsent(order.pk, () => order));
          // Requests constructed from PurchaseOrders.
          final requests = pos.map((po) => InvenTreeAPI()
              .get("/order/po-line/", params: {"order": po.pk.toString()}));
          // Wait till all are finished.
          return Future.wait(requests);
        }).then((responses) {
          // Create LineItems from JSON.
          final lis = responses.map((response) => response.data as List).map(
              (itemList) =>
                  itemList.map((li) => InvenTreePOLineItem.fromJson(li)));
          // Flatten the list
          final flat = lis.expand((i) => i).toList();
          // Only keep parts that are still waiting to be received.
          flat.retainWhere((li) => (li.quantity - li.received) > 0);
          // and map to requests.
          final requests = flat.map((li) {
            if (li.part > 0) {
              var list =
                  supplierPartIdToLineItemMap.putIfAbsent(li.part, () => []);
              // Cache the line item for later.
              list.add(li);

              return InvenTreeAPI()
                  .get("/company/part/${li.part}/", params: {});
            } else {
              return null;
            }
          }).whereType<Future<APIResponse>>(); // Only keep non-null.

          return Future.wait(requests);
        }).then((responses) => responses
            .map((response) => InvenTreeSupplierPart.fromJson(response.data))
            .toSet()
            .toList());
      },
      label: "Part",
      hint: "Select the received part",
      onChanged: (changed) {
        selectedSupplierPart = changed;
      },
      showClearButton: false,
      itemAsString: (item) {
        return item.description;
      },
      dropdownBuilder: (context, item, itemAsString) {
        return _buildSupplierPart(context, item, true, false);
      },
      popupItemBuilder: (context, item, isSelected) {
        return _buildSupplierPart(context, item, isSelected, true);
      },
      onSaved: (item) {
        // if (item != null) {
        //   data['value'] = item['pk'] ?? null;
        // } else {
        //   data['value'] = null;
        // }
      },
      // TODO: Implement filtering.
      isFilteredOnline: false,
      showSearchBox: true,
      autoFocusSearchBox: true,
      compareFn: (item, selectedItem) {
        // Comparison is based on the PK value
        if (selectedItem == null) {
          return false;
        }

        return item.pk == selectedItem.pk;
      });

  var poSearch = DropdownSearch<InvenTreePOLineItem>(
      mode: Mode.BOTTOM_SHEET,
      showSelectedItem: true,
      onFind: (String filter) async {
        var lineItems = supplierPartIdToLineItemMap[selectedSupplierPart!.pk];
        var orders = lineItems!;

        return orders.toList();
      },
      label: "Line item",
      hint: "Select the purchase order",
      onChanged: (changed) {
        selectedLineItem = changed;
      },
      showClearButton: false,
      itemAsString: (item) {
        return item.description;
      },
      dropdownBuilder: (context, item, itemAsString) {
        var po = orderMap[item?.order];

        return _renderPurchaseOrder(po, true, false);
      },
      popupItemBuilder: (context, item, isSelected) {
        var po = orderMap[item.order];

        return _renderPurchaseOrder(po, isSelected, true);
      },
      onSaved: (item) {
        // if (item != null) {
        //   data['value'] = item['pk'] ?? null;
        // } else {
        //   data['value'] = null;
        // }
      },
      // TODO: Implement filtering.
      isFilteredOnline: false,
      showSearchBox: true,
      autoFocusSearchBox: true,
      compareFn: (item, selectedItem) {
        // Comparison is based on the PK value
        if (selectedItem == null) {
          return false;
        }

        return item.pk == selectedItem.pk;
      });

  showFormDialog<bool>("Select Part", fields: [partSearch], callback: () {
    if (selectedSupplierPart != null) {
      print(
          "Selected ${selectedSupplierPart?.part.name} from ${selectedSupplierPart?.supplierName} as received.");

      if (supplierPartIdToLineItemMap.containsKey(selectedSupplierPart?.pk)) {
        int count =
            supplierPartIdToLineItemMap[selectedSupplierPart?.pk]?.length ?? 0;
        if (count == 1) {
          // Close the SelectPart dialog
          OneContext().popDialog(false);

          var lineItem =
              supplierPartIdToLineItemMap[selectedSupplierPart?.pk]?.first;

          _receiveLineItem(context, controller, lineItem!,
                  selectedSupplierPart!, barcodeHash)
              .then((val) {
            // Resume scanning when the dialog is closed.
            controller?.resumeCamera();
          });
        } else {
          // Close the SelectPart dialog
          OneContext().popDialog(false);

          showFormDialog("Select purchase order", fields: [poSearch],
              callback: () {
            // Close the SelectPurchaseOrder dialog
            OneContext().popDialog(false);

            print("Selected purchase order: $selectedLineItem");
            var po = orderMap[selectedLineItem!.order];

            _receiveLineItem(context, controller, selectedLineItem!,
                    selectedSupplierPart!, barcodeHash)
                .then((val) {
              // Resume scanning when the dialog is closed.
              controller?.resumeCamera();
            });
          }).then((val) {
            if (val == null || val == true) {
              // Resume scanning when the dialog is closed.
              controller?.resumeCamera();
            }
          });
        }
      }
    } else {
      // Nothing selected.
    }
  }).then((val) {
    if (val == null || val == true) {
      // Resume scanning when the dialog is closed.
      controller?.resumeCamera();
    }
  });
}

void _onAssignPart(BuildContext context, QRViewController? controller) {
  // Navigator.of(context).pop();
  // Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //         builder: (context) => LocationDisplayWidget(loc)));
}

class BarcodeScanHandler extends BarcodeHandler {
  /*
   * Class for general barcode scanning.
   * Scan *any* barcode without context, and then redirect app to correct view
   */

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanGeneral;

  @override
  Future<void> onBarcodeUnknown(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    String barcode_data = data["barcode_data"].toString();
    String hash = data["hash"].toString();

    // Valid barcode but unknown so far.
    if (barcode_data.isNotEmpty && hash.isNotEmpty) {
      var children = [
        ListTile(
            title: Text("Receive"),
            subtitle: Text("Select a Purchase Order to receive this to."),
            onTap: () {
              // Close AssignBarcode dialog.
              Navigator.of(context, rootNavigator: true).pop(false);

              _onReceiveLineItem(context, controller, hash);
            }),
        // ListTile(
        //     title: Text("Add stock"),
        //     subtitle: Text("Select a Part to assign this new stock to."),
        //     onTap: () {
        //       // Close dialog.
        //       Navigator.of(context, rootNavigator: true).pop(true);
        //
        //       _onAssignPart(context, controller);
        //     })
      ];

      successTone();
      OneContext().showDialog<bool>(builder: (context) {
        return SimpleDialog(
          title: ListTile(
              title: Text("Assign barcode"),
              subtitle: Text("Data: '${barcode_data}'\nHash: ${hash}"),
              leading: FaIcon(FontAwesomeIcons.barcode)),
          children: children,
        );
      }).then((val) {
        if (val == null || val == true) {
          // Resume scanning when the dialog is closed.
          controller?.resumeCamera();
        }
      });
    } else {
      failureTone();

      showSnackIcon(
        L10().barcodeNoMatch,
        icon: FontAwesomeIcons.exclamationCircle,
        success: false,
      );
      // Resume scanning.
      controller?.resumeCamera();
    }
  }

  @override
  Future<void> onBarcodeMatched(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    int pk = -1;

    // A stocklocation has been passed?
    if (data.containsKey('stocklocation')) {
      pk = (data['stocklocation']?['pk'] ?? -1) as int;

      if (pk > 0) {
        successTone();

        InvenTreeStockLocation().get(pk).then((var loc) {
          if (loc is InvenTreeStockLocation) {
            Navigator.of(context).pop();
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => LocationDisplayWidget(loc)));
          }
        });
      } else {
        failureTone();

        showSnackIcon(L10().invalidStockLocation, success: false);
      }
    } else if (data.containsKey('stockitem')) {
      pk = (data['stockitem']?['pk'] ?? -1) as int;

      if (pk > 0) {
        successTone();

        InvenTreeStockItem().get(pk).then((var item) {
          if (item is InvenTreeStockItem) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => StockDetailWidget(item)));
          }
        });
      } else {
        failureTone();

        showSnackIcon(L10().invalidStockItem, success: false);
      }
    } else if (data.containsKey('part')) {
      pk = (data['part']?['pk'] ?? -1) as int;

      if (pk > 0) {
        successTone();

        InvenTreePart().get(pk).then((var part) {
          // Dismiss the barcode scanner
          Navigator.of(context).pop();

          if (part is InvenTreePart) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PartDetailWidget(part)));
          }
        });
      } else {
        failureTone();

        showSnackIcon(L10().invalidPart, success: false);
      }
    } else {
      failureTone();

      showSnackIcon(L10().barcodeUnknown, success: false, onAction: () {
        OneContext().showDialog(
            builder: (BuildContext context) => SimpleDialog(
                  title: Text(L10().unknownResponse),
                  children: <Widget>[
                    ListTile(
                      title: Text(L10().responseData),
                      subtitle: Text(data.toString()),
                    )
                  ],
                ));
      });
    }
  }
}

class StockItemBarcodeAssignmentHandler extends BarcodeHandler {
  /*
   * Barcode handler for assigning a new barcode to a stock item
   */

  final InvenTreeStockItem item;

  StockItemBarcodeAssignmentHandler(this.item);

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanAssign;

  @override
  Future<void> onBarcodeMatched(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    failureTone();

    // If the barcode is known, we can't assign it to the stock item!
    showSnackIcon(L10().barcodeInUse,
        icon: FontAwesomeIcons.qrcode, success: false);
    // Resume scanning.
    controller?.resumeCamera();
  }

  @override
  Future<void> onBarcodeUnknown(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    // If the barcode is unknown, we *can* assign it to the stock item!

    if (!data.containsKey("hash")) {
      showServerError(
        L10().missingData,
        L10().barcodeMissingHash,
      );
    } else {
      // Send the 'hash' code as the UID for the stock item
      item.update(values: {
        "uid": data['hash'],
      }).then((result) {
        if (result) {
          failureTone();

          Navigator.of(context).pop();

          showSnackIcon(L10().barcodeAssigned,
              success: true, icon: FontAwesomeIcons.qrcode);
        } else {
          successTone();

          showSnackIcon(L10().barcodeNotAssigned,
              success: false, icon: FontAwesomeIcons.qrcode);
        }
      });
    }
    // Resume scanning.
    controller?.resumeCamera();
  }
}

class StockItemScanIntoLocationHandler extends BarcodeHandler {
  /*
   * Barcode handler for scanning a provided StockItem into a scanned StockLocation
   */

  final InvenTreeStockItem item;

  StockItemScanIntoLocationHandler(this.item);

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanLocation;

  @override
  Future<void> onBarcodeMatched(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    // If the barcode points to a 'stocklocation', great!
    if (data.containsKey('stocklocation')) {
      // Extract location information
      int location = (data['stocklocation']['pk'] ?? -1) as int;

      if (location == -1) {
        showSnackIcon(
          L10().invalidStockLocation,
          success: false,
        );

        return;
      }

      // Transfer stock to specified location
      final result = await item.transferStock(location);

      if (result) {
        successTone();

        Navigator.of(context).pop();

        showSnackIcon(
          L10().barcodeScanIntoLocationSuccess,
          success: true,
        );
      } else {
        failureTone();

        showSnackIcon(L10().barcodeScanIntoLocationFailure, success: false);
      }
    } else {
      failureTone();

      showSnackIcon(
        L10().invalidStockLocation,
        success: false,
      );
    }
    // Resume scanning.
    controller?.resumeCamera();
  }
}

class StockLocationScanInItemsHandler extends BarcodeHandler {
  /*
   * Barcode handler for scanning stock item(s) into the specified StockLocation
   */

  final InvenTreeStockLocation location;

  StockLocationScanInItemsHandler(this.location);

  @override
  String getOverlayText(BuildContext context) => L10().barcodeScanItem;

  @override
  Future<void> onBarcodeMatched(BuildContext context,
      QRViewController? controller, Map<String, dynamic> data) async {
    // Returned barcode must match a stock item
    if (data.containsKey('stockitem')) {
      int item_id = data['stockitem']['pk'] as int;

      final InvenTreeStockItem? item =
          await InvenTreeStockItem().get(item_id) as InvenTreeStockItem;

      if (item == null) {
        failureTone();

        showSnackIcon(
          L10().invalidStockItem,
          success: false,
        );
      } else if (item.locationId == location.pk) {
        failureTone();

        showSnackIcon(L10().itemInLocation, success: true);
      } else {
        final result = await item.transferStock(location.pk);

        if (result) {
          successTone();

          showSnackIcon(L10().barcodeScanIntoLocationSuccess, success: true);
        } else {
          failureTone();

          showSnackIcon(L10().barcodeScanIntoLocationFailure, success: false);
        }
      }
    } else {
      failureTone();
      // Does not match a valid stock item!
      showSnackIcon(
        L10().invalidStockItem,
        success: false,
      );
    }
    // Resume scanning.
    controller?.resumeCamera();
  }
}

class InvenTreeQRView extends StatefulWidget {
  final BarcodeHandler _handler;

  InvenTreeQRView(this._handler, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewState(_handler);
}

class _QRViewState extends State<InvenTreeQRView> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  QRViewController? _controller;

  final BarcodeHandler _handler;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();

    if (Platform.isAndroid) {
      _controller!.pauseCamera();
    }

    _controller!.resumeCamera();
  }

  _QRViewState(this._handler) : super();

  void _onViewCreated(BuildContext context, QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((barcode) {
      _handler.processBarcode(context, _controller, barcode.code);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(L10().scanBarcode),
        ),
        body: Stack(
          children: <Widget>[
            Column(children: [
              Expanded(
                  child: QRView(
                key: qrKey,
                onQRViewCreated: (QRViewController controller) {
                  _onViewCreated(context, controller);
                },
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.red,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 300,
                ),
              ))
            ]),
            Center(
                child: Column(children: [
              Spacer(),
              Padding(
                child: Text(
                  _handler.getOverlayText(context),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                padding: EdgeInsets.all(20),
              ),
            ]))
          ],
        ));
  }
}

Future<void> scanQrCode(BuildContext context) async {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => InvenTreeQRView(BarcodeScanHandler())));

  return;
}
