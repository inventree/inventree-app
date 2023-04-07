import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/api_form.dart";
import "package:inventree/preferences.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/part.dart";

import "package:inventree/widget/supplier_part_detail.dart";
import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/location_display.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock_item_history.dart";
import "package:inventree/widget/stock_item_test_results.dart";
import "package:inventree/widget/stock_notes.dart";


class StockDetailWidget extends StatefulWidget {

  const StockDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeStockItem item;

  @override
  _StockItemDisplayState createState() => _StockItemDisplayState();
}


class _StockItemDisplayState extends RefreshableState<StockDetailWidget> {

  _StockItemDisplayState();

  @override
  String getAppBarTitle(BuildContext context) => L10().stockItem;

  bool stockShowHistory = false;

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {

    List<SpeedDialChild> actions = [];

    if (api.supportsMixin("locate")) {
      actions.add(
        SpeedDialChild(
          child: Icon(Icons.travel_explore),
          label: L10().locateItem,
          onTap: () async {
            api.locateItemOrLocation(context, item: widget.item.pk);
          }
        )
      );
    }

    if (api.checkPermission("stock", "change")) {
      actions.add(
        SpeedDialChild(
          child: Icon(Icons.edit_square),
          label: L10().editItem,
          onTap: () {
            _editStockItem(context);
          }
        )
      );

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
          label: L10().transferStockDetail,
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
          onTap: () {
            _printLabel(context);
          }
        )
      );
    }

    if (api.checkPermission("stock", "delete")) {
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

    if (api.checkPermission("stock", "change")) {
      // Scan item into location
      actions.add(
          SpeedDialChild(
              child: Icon(Icons.qr_code_scanner),
              label: L10().scanIntoLocationDetail,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                        InvenTreeQRView(
                            StockItemScanIntoLocationHandler(widget.item)))
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

    stockShowHistory = await InvenTreeSettingsManager().getValue(INV_STOCK_SHOW_HISTORY, false) as bool;

    final bool result = widget.item.pk > 0 && await widget.item.reload();

    // Could not load this stock item for some reason
    // Perhaps it has been depleted?
    if (!result) {
      Navigator.of(context).pop();
    }

    // Request part information
    part = await InvenTreePart().get(widget.item.partId) as InvenTreePart?;

    // Request test results (async)
    widget.item.getTestResults().then((value) {

      if (mounted) {
        setState(() {
          // Update
        });
      }
    });

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

    // Request information on labels available for this stock item
    if (InvenTreeAPI().pluginsEnabled()) {
      _getLabels();
    }
  }

  Future <void> _getLabels() async {
    // Clear the existing labels list
    labels.clear();

    // If the server does not support label printing, don't bother!
    if (!InvenTreeAPI().supportsMixin("labels")) {
      return;
    }

    InvenTreeAPI().get(
        "/label/stock/",
        params: {
          "enabled": "true",
          "item": "${widget.item.pk}",
        },
    ).then((APIResponse response) {
      if (response.isValid() && response.statusCode == 200) {
        for (var label in response.data) {
          if (label is Map<String, dynamic>) {
            labels.add(label);
          }
        }

        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  /// Delete the stock item from the database
  Future<void> _deleteItem(BuildContext context) async {

    confirmationDialog(
      L10().stockItemDelete,
      L10().stockItemDeleteConfirm,
      icon: FontAwesomeIcons.trashCan,
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

  /// Opens a popup dialog allowing user to select a label for printing
  Future <void> _printLabel(BuildContext context) async {

    var plugins = InvenTreeAPI().getPlugins(mixin: "labels");

    dynamic initial_label;
    dynamic initial_plugin;

    List<Map<String, dynamic>> label_options = [];
    List<Map<String, dynamic>> plugin_options = [];

    for (var label in labels) {
      label_options.add({
        "display_name": label["description"],
        "value": label["pk"],
      });
    }

    for (var plugin in plugins) {
      plugin_options.add({
        "display_name": plugin.humanName,
        "value": plugin.key,
      });
    }

    if (labels.length == 1) {
      initial_label =  labels.first["pk"];
    }

    if (plugins.length == 1) {
      initial_plugin = plugins.first.key;
    }

    Map<String, dynamic> fields = {
      "label": {
        "label": L10().labelTemplate,
        "type": "choice",
        "value": initial_label,
        "choices": label_options,
        "required": true,
      },
      "plugin": {
        "label": L10().pluginPrinter,
        "type": "choice",
        "value": initial_plugin,
        "choices": plugin_options,
        "required": true,
      }
    };

    launchApiForm(
      context,
      L10().printLabel,
      "",
      fields,
      icon: FontAwesomeIcons.print,
      onSuccess: (Map<String, dynamic> data) async {
        int labelId = (data["label"] ?? -1) as int;
        String pluginKey = (data["plugin"] ?? "") as String;

        if (labelId != -1 && pluginKey.isNotEmpty) {
          String url = "/label/stock/${labelId}/print/?item=${widget.item.pk}&plugin=${pluginKey}";

          InvenTreeAPI().get(url).then((APIResponse response) {
            if (response.isValid() && response.statusCode == 200) {
              showSnackIcon(
                L10().printLabelSuccess,
                success: true
              );
            } else {
              showSnackIcon(
                L10().printLabelFailure,
                success: false,
              );
            }
          });
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
      "location": {},
      "notes": {},
    };

    if (widget.item.isSerialized()) {
      // Prevent editing of 'quantity' field if the item is serialized
      fields["quantity"]["hidden"] = true;
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
        leading: InvenTreeAPI().getImage(widget.item.partImage),
        trailing: Text(
            widget.item.statusLabel(),
          style: TextStyle(
            color: widget.item.statusColor
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
  List<Widget> detailTiles() {
    List<Widget> tiles = [];

    // Image / name / description
    tiles.add(headerTile());

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
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

    // Location information
    if ((widget.item.locationId > 0) && (widget.item.locationName.isNotEmpty)) {
      tiles.add(
          ListTile(
            title: Text(L10().stockLocation),
            subtitle: Text("${widget.item.locationPathString}"),
            leading: FaIcon(
              FontAwesomeIcons.locationDot,
              color: COLOR_CLICK,
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

    // Supplier part information (if available)
    if (widget.item.supplierPartId > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().supplierPart),
          subtitle: Text(widget.item.supplierSKU),
          leading: FaIcon(FontAwesomeIcons.building, color: COLOR_CLICK),
          trailing: InvenTreeAPI().getImage(
            widget.item.supplierImage,
            width: 40,
            height: 40,
          ),
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
          leading: FaIcon(FontAwesomeIcons.box),
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
          leading: FaIcon(FontAwesomeIcons.link, color: COLOR_CLICK),
          onTap: () {
            widget.item.openLink();
          },
        )
      );
    }

    if ((widget.item.testResultCount > 0) || (part?.isTrackable ?? false)) {
      tiles.add(
          ListTile(
              title: Text(L10().testResults),
              leading: FaIcon(FontAwesomeIcons.listCheck, color: COLOR_CLICK),
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
          leading: FaIcon(FontAwesomeIcons.clockRotateLeft, color: COLOR_CLICK),
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
        leading: FaIcon(FontAwesomeIcons.noteSticky, color: COLOR_CLICK),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StockNotesWidget(widget.item))
          );
        }
      )
    );

    tiles.add(
        ListTile(
          title: Text(L10().attachments),
          leading: FaIcon(FontAwesomeIcons.fileLines, color: COLOR_CLICK),
          trailing: attachmentCount > 0 ? Text(attachmentCount.toString()) : null,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AttachmentWidget(
                        InvenTreeStockItemAttachment(),
                        widget.item.pk,
                        InvenTreeAPI().checkPermission("stock", "change"))
                )
            );
          },
        )
    );

    return tiles;
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: ListTile.divideTiles(
          context: context,
          tiles: detailTiles()
      ).toList()
    );
  }
}