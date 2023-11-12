import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/api_form.dart";
import "package:inventree/labels.dart";
import "package:inventree/preferences.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/part.dart";

import "package:inventree/widget/company/supplier_part_detail.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/part/part_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock/stock_item_history.dart";
import "package:inventree/widget/stock/stock_item_test_results.dart";
import "package:inventree/widget/notes_widget.dart";


class StockDetailWidget extends StatefulWidget {

  const StockDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState();
}


class _StockItemDisplayState extends RefreshableState<StockDetailWidget> {

  _StockItemDisplayState();

  @override
  String getAppBarTitle() => L10().stockItem;

  bool stockShowHistory = false;
  bool stockShowTests = true;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (api.supportsMixin("locate")) {
      actions.add(
          IconButton(
            icon: Icon(Icons.travel_explore),
            tooltip: L10().locateItem,
            onPressed: () async {
              api.locateItemOrLocation(context, item: widget.item.pk);
            }
          )
      );
    }

    if (widget.item.canEdit) {
      actions.add(
          IconButton(
              icon: Icon(Icons.edit_square),
              tooltip: L10().editItem,
              onPressed: () {
                _editStockItem(context);
              }
          )
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {

    List<SpeedDialChild> actions = [];

    if (widget.item.canEdit) {

      // Stock adjustment actions available if item is *not* serialized
      if (!widget.item.isSerialized()) {

        actions.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.circleCheck, color: Colors.blue),
            label: L10().countStock,
            onTap: _countStockDialog,
          )
        );

        actions.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.circleMinus, color: Colors.red),
            label: L10().removeStock,
            onTap: _removeStockDialog,
          )
        );

        actions.add(
          SpeedDialChild(
            child: FaIcon(FontAwesomeIcons.circlePlus, color: Colors.green),
            label: L10().addStock,
            onTap: _addStockDialog,
          )
        );
      }

      // Transfer item
      actions.add(
        SpeedDialChild(
          child: Icon(Icons.trolley),
          label: L10().transferStock,
          onTap: () {
            _transferStockDialog(context);
          }
        )
      );
    }

    if (labels.isNotEmpty) {
      actions.add(
        SpeedDialChild(
          child: FaIcon(FontAwesomeIcons.print),
          label: L10().printLabel,
          onTap: () async {
            selectAndPrintLabel(
                context,
                labels,
                "stock",
                "item=${widget.item.pk}"
            );
          }
        )
      );
    }

    if (widget.item.canDelete) {
      actions.add(
          SpeedDialChild(
              child: FaIcon(FontAwesomeIcons.trashCan, color: Colors.red),
              label: L10().stockItemDelete,
              onTap: () {
                _deleteItem(context);
              }
          )
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.item.canEdit) {
      // Scan item into location
      actions.add(
          SpeedDialChild(
              child: Icon(Icons.qr_code_scanner),
              label: L10().scanIntoLocation,
              onTap: () {
                scanBarcode(
                  context,
                  handler: StockItemScanIntoLocationHandler(widget.item)
                ).then((ctx) {
                  refresh(context);
                });
              }
          )
      );

      if (api.supportModernBarcodes) {
        actions.add(
            customBarcodeAction(
                context, this,
                widget.item.customBarcode,
                "stockitem", widget.item.pk
            )
        );
      }
    }

    return actions;
  }

  // Is label printing enabled for this StockItem?
  // This will be determined when the widget is loaded
  List<Map<String, dynamic>> labels = [];

  // Part object
  InvenTreePart? part;

  int attachmentCount = 0;

  @override
  Future<void> onBuild(BuildContext context) async {
    // Load part data if not already loaded
    if (part == null) {
      refresh(context);
    }
  }

  @override
  Future<void> request(BuildContext context) async {
    await api.StockStatus.load();
    stockShowHistory = await InvenTreeSettingsManager().getValue(INV_STOCK_SHOW_HISTORY, false) as bool;
    stockShowTests = await InvenTreeSettingsManager().getValue(INV_STOCK_SHOW_TESTS, true) as bool;

    final bool result = widget.item.pk > 0 && await widget.item.reload();

    // Could not load this stock item for some reason
    // Perhaps it has been depleted?
    if (!result) {
      Navigator.of(context).pop();
    }

    // Request part information
    part = await InvenTreePart().get(widget.item.partId) as InvenTreePart?;

    stockShowTests &= part?.isTrackable ?? false;

    // Request test results (async)
    if (stockShowTests) {
      widget.item.getTestResults().then((value) {

        if (mounted) {
          setState(() {
            // Update
          });
        }
      });
    }

    // Request the number of attachments
    InvenTreeStockItemAttachment().count(
      filters: {
        "stock_item": widget.item.pk.toString()
      }
    ).then((int value) {

      if (mounted) {
        setState(() {
          attachmentCount = value;
        });
      }
    });

    List<Map<String, dynamic>> _labels = [];
    bool allowLabelPrinting = await InvenTreeSettingsManager().getBool(INV_ENABLE_LABEL_PRINTING, true);
    allowLabelPrinting &= api.supportsMixin("labels");

    // Request information on labels available for this stock item
    if (allowLabelPrinting) {
      // Clear the existing labels list
      _labels = await getLabelTemplates("stock", {
        "item": widget.item.pk.toString()
      });
    }

    if (mounted) {
      setState(() {
        labels = _labels;
      });
    }
  }

  /// Delete the stock item from the database
  Future<void> _deleteItem(BuildContext context) async {

    confirmationDialog(
      L10().stockItemDelete,
      L10().stockItemDeleteConfirm,
      icon: FontAwesomeIcons.trashCan,
      color: Colors.red,
      acceptText: L10().delete,
      onAccept: () async {
        final bool result = await widget.item.delete();
        
        if (result) {
          Navigator.of(context).pop();
          showSnackIcon(L10().stockItemDeleteSuccess, success: true);
        } else {
          showSnackIcon(L10().stockItemDeleteFailure, success: false);
        }
      },
    );

  }

  Future <void> _editStockItem(BuildContext context) async {

    var fields = InvenTreeStockItem().formFields();

    // Some fields we don't want to edit!
    fields.remove("part");
    fields.remove("quantity");
    fields.remove("location");
    fields.remove("serial_numbers");

    if (part == null || !part!.isTrackable) {
      fields.remove("serial");
    }

    widget.item.editForm(
      context,
      L10().editItem,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().stockItemUpdated, success: true);
      }
    );

  }

  /*
   * Launch a dialog to 'add' quantity to this StockItem
   */
  Future <void> _addStockDialog() async {

    Map<String, dynamic> fields = {
      "pk": {
        "parent": "items",
        "nested": true,
        "hidden": true,
        "value": widget.item.pk,
      },
      "quantity": {
        "parent": "items",
        "nested": true,
        "value": 0,
      },
      "notes": {},
    };

    launchApiForm(
      context,
      L10().addStock,
      InvenTreeStockItem.addStockUrl(),
      fields,
      method: "POST",
      icon: FontAwesomeIcons.circlePlus,
      onSuccess: (data) async {
        _stockUpdateMessage(true);
        refresh(context);
      }
    );
  }

  void _stockUpdateMessage(bool result) {

    if (result) {
      showSnackIcon(L10().stockItemUpdated, success: true);
    }
  }

  /*
   * Launch a dialog to 'remove' quantity from this StockItem
   */
  void _removeStockDialog() {

    Map<String, dynamic> fields = {
      "pk": {
        "parent": "items",
        "nested": true,
        "hidden": true,
        "value": widget.item.pk,
      },
      "quantity": {
        "parent": "items",
        "nested": true,
        "value": 0,
      },
      "notes": {},
    };

    launchApiForm(
        context,
        L10().removeStock,
        InvenTreeStockItem.removeStockUrl(),
        fields,
        method: "POST",
        icon: FontAwesomeIcons.circleMinus,
        onSuccess: (data) async {
          _stockUpdateMessage(true);
          refresh(context);
        }
    );
  }

  Future <void> _countStockDialog() async {

    Map<String, dynamic> fields = {
      "pk": {
        "parent": "items",
        "nested": true,
        "hidden": true,
        "value": widget.item.pk,
      },
      "quantity": {
        "parent": "items",
        "nested": true,
        "value": widget.item.quantity,
      },
      "notes": {},
    };

    launchApiForm(
        context,
        L10().countStock,
        InvenTreeStockItem.countStockUrl(),
        fields,
        method: "POST",
        icon: FontAwesomeIcons.clipboardCheck,
        onSuccess: (data) async {
          _stockUpdateMessage(true);
          refresh(context);
        }
    );
  }

  /*
   * Launches an API Form to transfer this stock item to a new location
   */
  Future <void> _transferStockDialog(BuildContext context) async {

    Map<String, dynamic> fields = {
      "pk": {
        "parent": "items",
        "nested": true,
        "hidden": true,
        "value": widget.item.pk,
      },
      "quantity": {
        "parent": "items",
        "nested": true,
        "value": widget.item.quantity,
      },
      "location": {
        "value": widget.item.locationId,
      },
      "status": {
        "parent": "items",
        "nested": true,
        "value": widget.item.status,
      },
      "packaging": {
        "parent": "items",
        "nested": true,
        "value": widget.item.packaging,
      },
      "notes": {},
    };

    if (widget.item.isSerialized()) {
      // Prevent editing of 'quantity' field if the item is serialized
      fields["quantity"]["hidden"] = true;
    }

    // Old API does not support these fields
    if (!api.supportsStockAdjustExtraFields) {
      fields.remove("packaging");
      fields.remove("status");
    }

    launchApiForm(
        context,
        L10().transferStock,
        InvenTreeStockItem.transferStockUrl(),
        fields,
        method: "POST",
        icon: FontAwesomeIcons.dolly,
        onSuccess: (data) async {
          _stockUpdateMessage(true);
          refresh(context);
        }
    );
  }

  Widget headerTile() {
    return Card(
      child: ListTile(
        title: Text("${widget.item.partName}"),
        subtitle: Text("${widget.item.partDescription}"),
        leading: InvenTreeAPI().getThumbnail(widget.item.partImage),
        trailing: Text(
          widget.item.quantityString(),
          style: TextStyle(
            fontSize: 20,
            color: api.StockStatus.color(widget.item.status),
          )
        ),
        onTap: () async {
          if (widget.item.partId > 0) {

            showLoadingOverlay(context);
            var part = await InvenTreePart().get(widget.item.partId);
            hideLoadingOverlay();

            if (part is InvenTreePart) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailWidget(part)));
            }
          }
        },
        //trailing: Text(item.serialOrQuantityDisplay()),
      )
    );
  }

  /*
   * Construct a list of detail elements about this StockItem.
   * The number of elements may vary depending on the StockItem details
   */
  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Image / name / description
    tiles.add(headerTile());

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    // Location information
    if ((widget.item.locationId > 0) && (widget.item.locationName.isNotEmpty)) {
      tiles.add(
        ListTile(
          title: Text(L10().stockLocation),
          subtitle: Text("${widget.item.locationPathString}"),
          leading: FaIcon(
            FontAwesomeIcons.locationDot,
            color: COLOR_ACTION,
          ),
          onTap: () async {
            if (widget.item.locationId > 0) {

              showLoadingOverlay(context);
              var loc = await InvenTreeStockLocation().get(widget.item.locationId);
              hideLoadingOverlay();

              if (loc is InvenTreeStockLocation) {
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => LocationDisplayWidget(loc)));
              }
            }
          },
        ),
      );
    } else {
      tiles.add(
          ListTile(
            title: Text(L10().stockLocation),
            leading: FaIcon(FontAwesomeIcons.locationDot),
            subtitle: Text(L10().locationNotSet),
          )
      );
    }

    // Quantity information
    if (widget.item.isSerialized()) {
      tiles.add(
          ListTile(
            title: Text(L10().serialNumber),
            leading: FaIcon(FontAwesomeIcons.hashtag),
            trailing: Text("${widget.item.serialNumber}"),
          )
      );
    } else {
      tiles.add(
          ListTile(
            title: widget.item.allocated > 0 ? Text(L10().quantityAvailable) : Text(L10().quantity),
            leading: FaIcon(FontAwesomeIcons.cubes),
            trailing: Text("${widget.item.quantityString()}"),
          )
      );
    }

    // Stock item status information
    tiles.add(
      ListTile(
        title: Text(L10().status),
        leading: FaIcon(FontAwesomeIcons.circleInfo),
        trailing: Text(
          api.StockStatus.label(widget.item.status),
          style: TextStyle(
            color: api.StockStatus.color(widget.item.status),
          )
        )
      )
    );

    // Supplier part information (if available)
    if (widget.item.supplierPartId > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().supplierPart),
          subtitle: Text(widget.item.supplierSKU),
          leading: FaIcon(FontAwesomeIcons.building, color: COLOR_ACTION),
          trailing: InvenTreeAPI().getThumbnail(widget.item.supplierImage, hideIfNull: true),
          onTap: () async {
            showLoadingOverlay(context);
            var sp = await InvenTreeSupplierPart().get(
                widget.item.supplierPartId);
            hideLoadingOverlay();
            if (sp is InvenTreeSupplierPart) {
              Navigator.push(
                  context, MaterialPageRoute(
                  builder: (context) => SupplierPartDetailWidget(sp))
              );
            }
          }
        )
      );
    }

    if (widget.item.isBuilding) {
      tiles.add(
        ListTile(
          title: Text(L10().inProduction),
          leading: FaIcon(FontAwesomeIcons.screwdriverWrench),
          subtitle: Text(L10().inProductionDetail),
          onTap: () {
            // TODO: Click through to the "build order"
          },
        )
      );
    }

    if (widget.item.batch.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().batchCode),
          subtitle: Text(widget.item.batch),
          leading: FaIcon(FontAwesomeIcons.layerGroup),
        )
      );
    }

    if (widget.item.packaging.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().packaging),
          subtitle: Text(widget.item.packaging),
          leading: FaIcon(FontAwesomeIcons.boxesPacking),
        )
      );
    }

    // Last update?
    if (widget.item.updatedDateString.isNotEmpty) {

      tiles.add(
        ListTile(
          title: Text(L10().lastUpdated),
          subtitle: Text(widget.item.updatedDateString),
          leading: FaIcon(FontAwesomeIcons.calendarDays)
        )
      );
    }

    // Stocktake?
    if (widget.item.stocktakeDateString.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().lastStocktake),
          subtitle: Text(widget.item.stocktakeDateString),
          leading: FaIcon(FontAwesomeIcons.calendarDays)
        )
      );
    }

    if (widget.item.link.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text("${widget.item.link}"),
          leading: FaIcon(FontAwesomeIcons.link, color: COLOR_ACTION),
          onTap: () {
            widget.item.openLink();
          },
        )
      );
    }

    if (stockShowTests || (widget.item.testResultCount > 0)) {
      tiles.add(
          ListTile(
              title: Text(L10().testResults),
              leading: FaIcon(FontAwesomeIcons.listCheck, color: COLOR_ACTION),
              trailing: Text("${widget.item.testResultCount}"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => StockItemTestResultsWidget(widget.item))
                ).then((ctx) {
                  refresh(context);
                });
              }
          )
      );
    }

    if (widget.item.hasPurchasePrice) {
      tiles.add(
        ListTile(
          title: Text(L10().purchasePrice),
          leading: FaIcon(FontAwesomeIcons.dollarSign),
          trailing: Text(
            renderCurrency(widget.item.purchasePrice, widget.item.purchasePriceCurrency)
          )
        )
      );
    }

    // TODO - Is this stock item linked to a PurchaseOrder?

    if (stockShowHistory && widget.item.trackingItemCount > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().history),
          leading: FaIcon(FontAwesomeIcons.clockRotateLeft, color: COLOR_ACTION),
          trailing: Text("${widget.item.trackingItemCount}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockItemHistoryWidget(widget.item))
              ).then((ctx) {
                refresh(context);
            });
          },
        )
      );
    }

    // Notes field
    tiles.add(
      ListTile(
        title: Text(L10().notes),
        leading: FaIcon(FontAwesomeIcons.noteSticky, color: COLOR_ACTION),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesWidget(widget.item))
          );
        }
      )
    );

    tiles.add(
        ListTile(
          title: Text(L10().attachments),
          leading: FaIcon(FontAwesomeIcons.fileLines, color: COLOR_ACTION),
          trailing: attachmentCount > 0 ? Text(attachmentCount.toString()) : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttachmentWidget(
                  InvenTreeStockItemAttachment(),
                  widget.item.pk,
                  widget.item.canEdit,
                )
              )
            );
          },
        )
    );

    return tiles;
  }

}