import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";

import "package:inventree/inventree/bom.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/labels.dart";
import "package:inventree/preferences.dart";

import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/part/bom_list.dart";
import "package:inventree/widget/part/part_list.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/part/part_parameter_widget.dart";
import "package:inventree/widget/part/part_pricing.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/part/part_image_widget.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock/stock_list.dart";
import "package:inventree/widget/company/supplier_part_list.dart";

/*
 * Widget for displaying a detail view of a single Part instance
 */
class PartDetailWidget extends StatefulWidget {
  const PartDetailWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartDisplayState createState() => _PartDisplayState(part);
}

class _PartDisplayState extends RefreshableState<PartDetailWidget> {
  _PartDisplayState(this.part);

  InvenTreePart part;

  InvenTreePart? parentPart;

  InvenTreeStockLocation? defaultLocation;

  int parameterCount = 0;

  bool allowLabelPrinting = false;
  bool showParameters = false;
  bool showBom = false;
  bool showPricing = false;

  int attachmentCount = 0;
  int bomCount = 0;
  int usedInCount = 0;
  int variantCount = 0;

  InvenTreePartPricing? partPricing;

  List<Map<String, dynamic>> labels = [];

  @override
  String getAppBarTitle() => L10().partDetails;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreePart().canEdit) {
      actions.add(
        IconButton(
          icon: Icon(TablerIcons.edit),
          tooltip: L10().editPart,
          onPressed: () {
            _editPartDialog(context);
          },
        ),
      );
    }
    return actions;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreePart().canEdit) {
      actions.add(
        customBarcodeAction(
          context,
          this,
          widget.part.customBarcode,
          "part",
          widget.part.pk,
        ),
      );
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreeStockItem().canCreate) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.packages),
          label: L10().stockItemCreate,
          onTap: () {
            _newStockItem(context);
          },
        ),
      );
    }

    if (labels.isNotEmpty) {
      actions.add(
        SpeedDialChild(
          child: Icon(TablerIcons.printer),
          label: L10().printLabel,
          onTap: () async {
            selectAndPrintLabel(
              context,
              labels,
              widget.part.pk,
              "part",
              "part=${widget.part.pk}",
            );
          },
        ),
      );
    }

    return actions;
  }

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh(context);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Future<void> request(BuildContext context) async {
    final bool result = await part.reload();

    // Load page settings from local storage
    showPricing = await InvenTreeSettingsManager().getBool(
      INV_PART_SHOW_PRICING,
      true,
    );
    showParameters = await InvenTreeSettingsManager().getBool(
      INV_PART_SHOW_PARAMETERS,
      true,
    );
    showBom = await InvenTreeSettingsManager().getBool(INV_PART_SHOW_BOM, true);
    allowLabelPrinting = await InvenTreeSettingsManager().getBool(
      INV_ENABLE_LABEL_PRINTING,
      true,
    );

    if (!result || part.pk == -1) {
      // Part could not be loaded, for some reason
      Navigator.of(context).pop();
      return;
    }

    // If the part points to a parent "template" part, request that too
    int? templatePartId = part.variantOf;

    if (templatePartId != null) {
      InvenTreePart().get(templatePartId).then((value) {
        if (mounted) {
          setState(() {
            parentPart = value as InvenTreePart?;
          });
        }
      });
    } else if (mounted) {
      setState(() {
        parentPart = null;
      });
    }

    // Request part test templates
    if (part.isTestable) {
      part.getTestTemplates().then((value) {
        if (mounted) {
          setState(() {});
        }
      });
    }

    // Request the number of attachments
    InvenTreePartAttachment().countAttachments(part.pk).then((int value) {
      if (mounted) {
        setState(() {
          attachmentCount = value;
        });
      }
    });

    // If show pricing information?
    if (showPricing) {
      part.getPricing().then((InvenTreePartPricing? pricing) {
        if (mounted) {
          setState(() {
            partPricing = pricing;
          });
        }
      });
    }

    // Request the number of BOM items
    InvenTreePart().count(filters: {"in_bom_for": part.pk.toString()}).then((
      int value,
    ) {
      if (mounted) {
        setState(() {
          bomCount = value;
        });
      }
    });

    // Request number of "used in" parts
    InvenTreeBomItem().count(filters: {"uses": part.pk.toString()}).then((
      int value,
    ) {
      if (mounted) {
        setState(() {
          usedInCount = value;
        });
      }
    });

    // Request the number of variant items
    InvenTreePart().count(filters: {"variant_of": part.pk.toString()}).then((
      int value,
    ) {
      if (mounted) {
        setState(() {
          variantCount = value;
        });
      }
    });

    List<Map<String, dynamic>> _labels = [];
    allowLabelPrinting &= api.supportsMixin("labels");

    if (allowLabelPrinting) {
      String model_type = api.supportsModernLabelPrinting
          ? InvenTreePart.MODEL_TYPE
          : "part";
      String item_key = api.supportsModernLabelPrinting ? "items" : "part";

      _labels = await getLabelTemplates(model_type, {
        item_key: widget.part.pk.toString(),
      });
    }

    if (mounted) {
      setState(() {
        labels = _labels;
      });
    }
  }

  void _editPartDialog(BuildContext context) {
    part.editForm(
      context,
      L10().editPart,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().partEdited, success: true);
      },
    );
  }

  Widget headerTile() {
    return Card(
      child: ListTile(
        title: Text(part.fullname),
        subtitle: Text(part.description),
        trailing: Text(part.stockString(), style: TextStyle(fontSize: 20)),
        leading: GestureDetector(
          child: api.getImage(part.thumbnail),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PartImageWidget(part)),
            ).then((value) {
              refresh(context);
            });
          },
        ),
      ),
    );
  }

  /*
   * Build a list of tiles to display under the part description
   */
  List<Widget> partTiles() {
    List<Widget> tiles = [];

    // Image / name / description
    tiles.add(headerTile());

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    if (!part.isActive) {
      tiles.add(
        ListTile(
          title: Text(L10().inactive, style: TextStyle(color: COLOR_DANGER)),
          subtitle: Text(
            L10().inactiveDetail,
            style: TextStyle(color: COLOR_DANGER),
          ),
          leading: Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER),
        ),
      );
    }

    if (parentPart != null) {
      tiles.add(
        ListTile(
          title: Text(L10().templatePart),
          subtitle: Text(parentPart!.fullname),
          leading: api.getImage(parentPart!.thumbnail, width: 32, height: 32),
          trailing: LinkIcon(),
          onTap: () {
            parentPart?.goToDetailPage(context);
          },
        ),
      );
    }

    // Category information
    if (part.categoryName.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().partCategory),
          subtitle: Text("${part.categoryName}"),
          leading: Icon(TablerIcons.sitemap, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () async {
            if (part.categoryId > 0) {
              showLoadingOverlay();
              var cat = await InvenTreePartCategory().get(part.categoryId);
              hideLoadingOverlay();

              if (cat is InvenTreePartCategory) {
                cat.goToDetailPage(context);
              }
            }
          },
        ),
      );
    } else {
      tiles.add(
        ListTile(
          title: Text(L10().partCategory),
          subtitle: Text(L10().partCategoryTopLevel),
          leading: Icon(TablerIcons.sitemap, color: COLOR_ACTION),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryDisplayWidget(null),
              ),
            );
          },
        ),
      );
    }

    // Display number of "variant" parts if any exist
    if (variantCount > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().variants),
          leading: Icon(TablerIcons.versions, color: COLOR_ACTION),
          trailing: LinkIcon(text: variantCount.toString()),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PartList({
                  "variant_of": part.pk.toString(),
                }, title: L10().variants),
              ),
            );
          },
        ),
      );
    }

    tiles.add(
      ListTile(
        title: Text(L10().availableStock),
        subtitle: Text(L10().stockDetails),
        leading: Icon(TablerIcons.packages),
        trailing: LargeText(part.stockString()),
      ),
    );

    if (showPricing && partPricing != null) {
      String pricing = formatPriceRange(
        partPricing?.overallMin,
        partPricing?.overallMax,
        currency: partPricing?.currency,
      );

      tiles.add(
        ListTile(
          title: Text(L10().partPricing),
          subtitle: Text(
            pricing.isNotEmpty ? pricing : L10().noPricingAvailable,
          ),
          leading: Icon(TablerIcons.currency_dollar, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PartPricingWidget(part: part, partPricing: partPricing),
              ),
            );
          },
        ),
      );
    }

    // Tiles for "purchaseable" parts
    if (part.isPurchaseable) {
      // On order
      tiles.add(
        ListTile(
          title: Text(L10().onOrder),
          subtitle: Text(L10().onOrderDetails),
          leading: Icon(TablerIcons.shopping_cart),
          trailing: LargeText("${part.onOrderString}"),
          onTap: () {
            // TODO - Order views
          },
        ),
      );
    }

    // Tiles for an "assembly" part
    if (part.isAssembly) {
      if (showBom && bomCount > 0) {
        tiles.add(
          ListTile(
            title: Text(L10().billOfMaterials),
            leading: Icon(TablerIcons.list_tree, color: COLOR_ACTION),
            trailing: LinkIcon(text: bomCount.toString()),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BillOfMaterialsWidget(part, isParentComponent: true),
                ),
              );
            },
          ),
        );
      }

      if (part.building > 0) {
        tiles.add(
          ListTile(
            title: Text(L10().building),
            leading: Icon(TablerIcons.tools),
            trailing: LargeText("${simpleNumberString(part.building)}"),
            onTap: () {
              // TODO: List of active build orders?
            },
          ),
        );
      }
    }

    if (part.isComponent) {
      if (showBom && usedInCount > 0) {
        tiles.add(
          ListTile(
            title: Text(L10().usedIn),
            subtitle: Text(L10().usedInDetails),
            leading: Icon(TablerIcons.stack_2, color: COLOR_ACTION),
            trailing: LinkIcon(text: usedInCount.toString()),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BillOfMaterialsWidget(part, isParentComponent: false),
                ),
              );
            },
          ),
        );
      }
    }

    // Keywords?
    if (part.keywords.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text("${part.keywords}"),
          leading: Icon(TablerIcons.tags),
        ),
      );
    }

    // External link?
    if (part.hasLink) {
      tiles.add(
        ListTile(
          title: Text("${part.link}"),
          leading: Icon(TablerIcons.link, color: COLOR_ACTION),
          onTap: () {
            part.openLink();
          },
        ),
      );
    }

    // Tiles for "component" part
    if (part.isComponent && part.usedInCount > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().usedIn),
          subtitle: Text(L10().usedInDetails),
          leading: Icon(TablerIcons.sitemap),
          trailing: LargeText("${part.usedInCount}"),
          onTap: () {
            // TODO: Show assemblies which use this part
          },
        ),
      );
    }

    if (part.isPurchaseable) {
      if (part.supplierCount > 0) {
        tiles.add(
          ListTile(
            title: Text(L10().suppliers),
            leading: Icon(TablerIcons.building_factory, color: COLOR_ACTION),
            trailing: LinkIcon(text: "${part.supplierCount}"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SupplierPartList({"part": part.pk.toString()}),
                ),
              );
            },
          ),
        );
      }
    }

    // Notes field
    tiles.add(
      ListTile(
        title: Text(L10().notes),
        leading: Icon(TablerIcons.note, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesWidget(part)),
          );
        },
      ),
    );

    tiles.add(
      ListTile(
        title: Text(L10().attachments),
        leading: Icon(TablerIcons.file, color: COLOR_ACTION),
        trailing: LinkIcon(
          text: attachmentCount > 0 ? attachmentCount.toString() : null,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttachmentWidget(
                InvenTreePartAttachment(),
                part.pk,
                L10().part,
                part.canEdit,
              ),
            ),
          );
        },
      ),
    );

    return tiles;
  }

  // Return tiles for each stock item
  List<Widget> stockTiles() {
    List<Widget> tiles = [];

    tiles.add(headerTile());

    tiles.add(
      ListTile(
        title: Text(
          L10().stockItems,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: part.stockItems.isEmpty
            ? Text(L10().stockItemsNotAvailable)
            : null,
        trailing: part.stockItems.isNotEmpty
            ? Text("${part.stockItems.length}")
            : null,
      ),
    );

    return tiles;
  }

  /*
   * Launch a form to create a new StockItem for this part
   */
  Future<void> _newStockItem(BuildContext context) async {
    var fields = InvenTreeStockItem().formFields();

    // Serial number cannot be directly edited here
    fields.remove("serial");

    // Hide the "part" field
    fields["part"]?["hidden"] = true;

    int? default_location = part.defaultLocation;

    Map<String, dynamic> data = {"part": part.pk.toString()};

    if (default_location != null) {
      data["location"] = default_location;
    }

    if (part.isTrackable) {
      // read the next available serial number
      showLoadingOverlay();
      var response = await api.get(
        "/api/part/${part.pk}/serial-numbers/",
        expectedStatusCode: null,
      );
      hideLoadingOverlay();

      if (response.isValid() && response.statusCode == 200) {
        data["serial_numbers"] =
            response.data["next"] ?? response.data["latest"];
      }

      print(
        "response: " +
            response.statusCode.toString() +
            response.data.toString(),
      );
    } else {
      // Cannot set serial numbers for non-trackable parts
      fields.remove("serial_numbers");
    }

    print("data: ${data.toString()}");

    InvenTreeStockItem().createForm(
      context,
      L10().stockItemCreate,
      fields: fields,
      data: data,
      onSuccess: (result) async {
        Map<String, dynamic> data = result as Map<String, dynamic>;

        if (data.containsKey("pk")) {
          var item = InvenTreeStockItem.fromJson(data);
          item.goToDetailPage(context);
        }
      },
    );
  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    List<Widget> icons = [Tab(text: L10().details), Tab(text: L10().stock)];

    if (showParameters) {
      icons.add(Tab(text: L10().parameters));
    }

    return icons;
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    List<Widget> tabs = [
      SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(children: partTiles()),
      ),
      PaginatedStockItemList({"part": part.pk.toString()}),
    ];

    if (showParameters) {
      tabs.add(PaginatedParameterList({"part": part.pk.toString()}));
    }

    return tabs;
  }
}
