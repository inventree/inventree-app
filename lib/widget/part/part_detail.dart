import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

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
import "package:inventree/widget/part/bom_list.dart";
import "package:inventree/widget/part/part_list.dart";
import "package:inventree/widget/notes_widget.dart";
import "package:inventree/widget/part/part_parameter_widget.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/part/category_display.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/part/part_image_widget.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock/stock_detail.dart";
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

  int parameterCount = 0;

  bool showParameters = false;
  bool showBom = false;

  int attachmentCount = 0;
  int bomCount = 0;
  int usedInCount = 0;
  int variantCount = 0;

  List<Map<String, dynamic>> labels = [];

  @override
  String getAppBarTitle() => L10().partDetails;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (InvenTreePart().canEdit) {
      actions.add(
          IconButton(
              icon: Icon(Icons.edit_square),
              tooltip: L10().editPart,
              onPressed: () {
                _editPartDialog(context);
              }
          )
      );
    }
    return actions;
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreePart().canEdit) {
      if (api.supportModernBarcodes) {
        actions.add(
            customBarcodeAction(
                context, this,
                widget.part.customBarcode, "part",
                widget.part.pk
            )
        );
      }
    }

    return actions;
  }

  @override
  List<SpeedDialChild> actionButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (InvenTreeStockItem().canCreate) {
      actions.add(
          SpeedDialChild(
              child: FaIcon(FontAwesomeIcons.box),
              label: L10().stockItemCreate,
              onTap: () {
                _newStockItem(context);
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
              "part",
              "part=${widget.part.pk}"
            );
          }
        )
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

    if (!result || part.pk == -1) {
      // Part could not be loaded, for some reason
      Navigator.of(context).pop();
      return;
    }

    // If the part points to a parent "template" part, request that too
    int? templatePartId = part.variantOf;

    if (templatePartId == null) {
      parentPart = null;
    } else {
      final result = await InvenTreePart().get(templatePartId);

      if (result != null && result is InvenTreePart) {
        parentPart = result;
      } else {
        parentPart = null;
      }
    }

    // Request part test templates
    part.getTestTemplates().then((value) {
      if (mounted) {
        setState(() {});
      }
    });

    // Request the number of parameters for this part
    if (api.supportsPartParameters) {
      showParameters = await InvenTreeSettingsManager().getValue(INV_PART_SHOW_PARAMETERS, true) as bool;
    } else {
      showParameters = false;
    }

    // Request the number of attachments
    InvenTreePartAttachment().count(
      filters: {
        "part": part.pk.toString(),
      }
    ).then((int value) {
      if (mounted) {
        setState(() {
          attachmentCount = value;
        });
      }
    });

    showBom = await InvenTreeSettingsManager().getValue(INV_PART_SHOW_BOM, true) as bool;

    // Request the number of BOM items
    InvenTreePart().count(
      filters: {
        "in_bom_for": part.pk.toString(),
      }
    ).then((int value) {
      if (mounted) {
        setState(() {
          bomCount = value;
        });
      }
    });

    // Request number of "used in" parts
    InvenTreeBomItem().count(
      filters: {
        "uses": part.pk.toString(),
      }
    ).then((int value) {
      if (mounted) {
        setState(() {
          usedInCount = value;
        });
      }
    });

    // Request the number of variant items
    InvenTreePart().count(
      filters: {
        "variant_of": part.pk.toString(),
      }
    ).then((int value) {
      if (mounted) {
        setState(() {
          variantCount = value;
        });
      }
    });

    List<Map<String, dynamic>> _labels = [];
    bool allowLabelPrinting = await InvenTreeSettingsManager().getBool(INV_ENABLE_LABEL_PRINTING, true);
    allowLabelPrinting &= api.supportsMixin("labels");

    if (allowLabelPrinting) {
      _labels = await getLabelTemplates("part", {
        "part": widget.part.pk.toString(),
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
      }
    );
  }

  Widget headerTile() {
    return Card(
        child: ListTile(
          title: Text("${part.fullname}"),
          subtitle: Text("${part.description}"),
          trailing: Text(
            part.stockString(),
            style: TextStyle(
              fontSize: 20,
            )
          ),
          leading: GestureDetector(
            child: api.getImage(part.thumbnail),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PartImageWidget(part)
                )
              ).then((value) {
                refresh(context);
              });
            }),
        ),
    );
  }

  /*
   * Build a list of tiles to display under the part description
   */
  List<Widget> partTiles() {

    List<Widget> tiles = [];

    // Image / name / description
    tiles.add(
      headerTile()
    );

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    if (!part.isActive) {
      tiles.add(
        ListTile(
          title: Text(
              L10().inactive,
              style: TextStyle(
                color: COLOR_DANGER
              )
          ),
          subtitle: Text(
            L10().inactiveDetail,
            style: TextStyle(
              color: COLOR_DANGER
            )
          ),
          leading: FaIcon(
              FontAwesomeIcons.circleExclamation,
              color: COLOR_DANGER
          ),
        )
      );
    }

    if (parentPart != null) {
      tiles.add(
        ListTile(
          title: Text(L10().templatePart),
          subtitle: Text(parentPart!.fullname),
          leading: api.getImage(
            parentPart!.thumbnail,
            width: 32,
            height: 32,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PartDetailWidget(parentPart!))
            );
          }
        )
      );
    }

    // Category information
    if (part.categoryName.isNotEmpty) {
      tiles.add(
        ListTile(
            title: Text(L10().partCategory),
            subtitle: Text("${part.categoryName}"),
            leading: FaIcon(FontAwesomeIcons.sitemap, color: COLOR_ACTION),
            onTap: () async {
              if (part.categoryId > 0) {

                showLoadingOverlay(context);
                var cat = await InvenTreePartCategory().get(part.categoryId);
                hideLoadingOverlay();

                if (cat is InvenTreePartCategory) {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CategoryDisplayWidget(cat)));
                }
              }
            },
          )
      );
    } else {
      tiles.add(
          ListTile(
            title: Text(L10().partCategory),
            subtitle: Text(L10().partCategoryTopLevel),
            leading: FaIcon(FontAwesomeIcons.sitemap, color: COLOR_ACTION),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CategoryDisplayWidget(null)));
            },
          )
      );
    }

    // Display number of "variant" parts if any exist
    if (variantCount > 0) {
      tiles.add(
          ListTile(
            title: Text(L10().variants),
            leading: FaIcon(FontAwesomeIcons.shapes, color: COLOR_ACTION),
            trailing: Text(variantCount.toString()),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PartList(
                          {
                            "variant_of": part.pk.toString(),
                          },
                          title: L10().variants
                      )
                  )
              );
            },
          )
      );
    }

    tiles.add(
      ListTile(
        title: Text(L10().availableStock),
        subtitle: Text(L10().stockDetails),
        leading: FaIcon(FontAwesomeIcons.boxesStacked),
        trailing: Text(
          part.stockString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Tiles for "purchaseable" parts
    if (part.isPurchaseable) {

      // On order
      tiles.add(
        ListTile(
          title: Text(L10().onOrder),
          subtitle: Text(L10().onOrderDetails),
          leading: FaIcon(FontAwesomeIcons.cartShopping),
          trailing: Text("${part.onOrderString}"),
          onTap: () {
            // TODO - Order views
          },
        )
      );

    }

    // Tiles for an "assembly" part
    if (part.isAssembly) {

      if (showBom && bomCount > 0) {
        tiles.add(
            ListTile(
                title: Text(L10().billOfMaterials),
                leading: FaIcon(FontAwesomeIcons.tableList, color: COLOR_ACTION),
                trailing: Text(bomCount.toString()),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => BillOfMaterialsWidget(part, isParentComponent: true)
                  ));
                },
            )
        );
      }

      if (part.building > 0) {
        tiles.add(
            ListTile(
              title: Text(L10().building),
              leading: FaIcon(FontAwesomeIcons.screwdriverWrench),
              trailing: Text("${simpleNumberString(part.building)}"),
              onTap: () {
                // TODO
              },
            )
        );
      }
    }

    if (part.isComponent) {
      if (showBom && usedInCount > 0) {
        tiles.add(
          ListTile(
            title: Text(L10().usedIn),
            subtitle: Text(L10().usedInDetails),
            leading: FaIcon(FontAwesomeIcons.layerGroup, color: COLOR_ACTION),
            trailing: Text(usedInCount.toString()),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => BillOfMaterialsWidget(part, isParentComponent: false)
                    )
                );
              }
          )
        );
      }
    }

    // Keywords?
    if (part.keywords.isNotEmpty) {
      tiles.add(
          ListTile(
            title: Text("${part.keywords}"),
            leading: FaIcon(FontAwesomeIcons.tags),
          )
      );
    }

    // External link?
    if (part.link.isNotEmpty) {
      tiles.add(
          ListTile(
            title: Text("${part.link}"),
            leading: FaIcon(FontAwesomeIcons.link, color: COLOR_ACTION),
            onTap: () {
              part.openLink();
            },
          )
      );
    }

    // Tiles for "component" part
    if (part.isComponent && part.usedInCount > 0) {

      tiles.add(
        ListTile(
          title: Text(L10().usedIn),
          subtitle: Text(L10().usedInDetails),
          leading: FaIcon(FontAwesomeIcons.sitemap),
          trailing: Text("${part.usedInCount}"),
          onTap: () {
            // TODO
          },
        )
      );
    }

    if (part.isPurchaseable) {

      if (part.supplierCount > 0) {
        tiles.add(
            ListTile(
              title: Text(L10().suppliers),
              leading: FaIcon(FontAwesomeIcons.industry, color: COLOR_ACTION),
              trailing: Text("${part.supplierCount}"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SupplierPartList({
                      "part": part.pk.toString()
                    }))
                  );
                },
            )
        );
      }
    }

    // Notes field
    tiles.add(
        ListTile(
          title: Text(L10().notes),
          leading: FaIcon(FontAwesomeIcons.noteSticky, color: COLOR_ACTION),
          trailing: Text(""),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotesWidget(part))
            );
          },
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
                  InvenTreePartAttachment(),
                  part.pk,
                  part.canEdit
                )
            )
          );
        },
      )
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
        subtitle: part.stockItems.isEmpty ? Text(L10().stockItemsNotAvailable) : null,
        trailing: part.stockItems.isNotEmpty ? Text("${part.stockItems.length}") : null,
      )
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

    Map<String, dynamic> data = {
      "part": part.pk.toString()
    };

    if (default_location != null) {
      data["location"] = default_location;
    }

    if (part.isTrackable) {
      // read the next available serial number
      showLoadingOverlay(context);
      var response = await api.get("/api/part/${part.pk}/serial-numbers/", expectedStatusCode: null);
      hideLoadingOverlay();

      if (response.isValid() && response.statusCode == 200) {
        data["serial_numbers"] = response.data["next"] ?? response.data["latest"];
      }

      print("response: " + response.statusCode.toString() + response.data.toString());

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

            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => StockDetailWidget(item)
                )
            );
          }
        }
    );
  }

  @override
  List<Widget> getTabIcons(BuildContext context) {
    List<Widget> icons = [
      Tab(text: L10().details),
      Tab(text: L10().stock)
    ];

    if (showParameters) {
      icons.add(Tab(text: L10().parameters));
    }

    return icons;
  }

  @override
  List<Widget> getTabs(BuildContext context) {
    List<Widget> tabs = [
      Center(
        child: ListView(
          children: ListTile.divideTiles(
          context: context,
          tiles: partTiles()
          ).toList()
        )
      ),
      PaginatedStockItemList({"part": part.pk.toString()})
    ];

    if (showParameters) {
      tabs.add(PaginatedParameterList({"part": part.pk.toString()}));
    }

    return tabs;
  }

}
