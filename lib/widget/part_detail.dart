import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode.dart";
import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";

import "package:inventree/inventree/bom.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/preferences.dart";

import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/bom_list.dart";
import "package:inventree/widget/part_list.dart";
import "package:inventree/widget/part_notes.dart";
import "package:inventree/widget/part_parameter_widget.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/category_display.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/part_image_widget.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/stock_detail.dart";
import "package:inventree/widget/stock_list.dart";


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

  @override
  String getAppBarTitle(BuildContext context) => L10().partDetails;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission("part", "view")) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.globe),
          onPressed: _openInvenTreePage,
        ),
      );
    }

    if (InvenTreeAPI().checkPermission("part", "change")) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.edit),
          tooltip: L10().edit,
          onPressed: () {
            _editPartDialog(context);
          },
        )
      );
    }

    return actions;
  }

  Future<void> _openInvenTreePage() async {
    part.goToInvenTreePage();
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
    if (InvenTreeAPI().supportsPartParameters) {

      showParameters = await InvenTreeSettingsManager().getValue(INV_PART_SHOW_PARAMETERS, true) as bool;

      InvenTreePartParameter().count(
          filters: {
            "part": part.pk.toString(),
          }
      ).then((int value) {
        if (mounted) {
          setState(() {
            parameterCount = value;
          });
        }
      });
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
  }


  /*
   * Toggle the "star" status of this paricular part
   */
  Future <void> _toggleStar(BuildContext context) async {

    if (InvenTreeAPI().checkPermission("part", "view")) {
      showLoadingOverlay(context);
      await part.update(values: {"starred": "${!part.starred}"});
      hideLoadingOverlay();
      refresh(context);
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
          trailing: IconButton(
            icon: FaIcon(part.starred ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star,
              color: part.starred ? COLOR_STAR : null,
            ),
            onPressed: () {
              _toggleStar(context);
            },
          ),
          leading: GestureDetector(
            child: InvenTreeAPI().getImage(part.thumbnail),
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
              FontAwesomeIcons.exclamationCircle,
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
          leading: InvenTreeAPI().getImage(
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
            leading: FaIcon(FontAwesomeIcons.sitemap, color: COLOR_CLICK),
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
            leading: FaIcon(FontAwesomeIcons.sitemap, color: COLOR_CLICK),
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
            leading: FaIcon(FontAwesomeIcons.shapes, color: COLOR_CLICK),
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
        leading: FaIcon(FontAwesomeIcons.boxes, color: COLOR_CLICK),
        trailing: Text(
          part.stockString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () {
          setState(() {
            tabIndex = 1;
          });
        },
      ),
    );

    // Tiles for "purchaseable" parts
    if (part.isPurchaseable) {

      // On order
      tiles.add(
        ListTile(
          title: Text(L10().onOrder),
          subtitle: Text(L10().onOrderDetails),
          leading: FaIcon(FontAwesomeIcons.shoppingCart),
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
                leading: FaIcon(FontAwesomeIcons.thList, color: COLOR_CLICK),
                trailing: Text(bomCount.toString()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BillOfMaterialsWidget(part)
                    )
                  );
                }
            )
        );
      }

      if (part.building > 0) {
        tiles.add(
            ListTile(
              title: Text(L10().building),
              leading: FaIcon(FontAwesomeIcons.tools),
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
            leading: FaIcon(FontAwesomeIcons.layerGroup, color: COLOR_CLICK),
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
            leading: FaIcon(FontAwesomeIcons.link, color: COLOR_CLICK),
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
      tiles.add(
          ListTile(
            title: Text(L10().suppliers),
            leading: FaIcon(FontAwesomeIcons.industry),
            trailing: Text("${part.supplierCount}"),
            /* TODO:
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PartSupplierWidget(part))
                );
              },
               */
          )
      );
    }

    if (showParameters) {
      tiles.add(
          ListTile(
              title: Text(L10().parameters),
              leading: FaIcon(FontAwesomeIcons.thList, color: COLOR_CLICK),
              trailing: parameterCount > 0 ? Text(parameterCount.toString()) : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PartParameterWidget(part)
                  )
                );
              }
          )
      );
    }

    // Notes field
    tiles.add(
        ListTile(
          title: Text(L10().notes),
          leading: FaIcon(FontAwesomeIcons.stickyNote, color: COLOR_CLICK),
          trailing: Text(""),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PartNotesWidget(part))
            );
          },
        )
    );

    tiles.add(
      ListTile(
        title: Text(L10().attachments),
        leading: FaIcon(FontAwesomeIcons.fileAlt, color: COLOR_CLICK),
        trailing: attachmentCount > 0 ? Text(attachmentCount.toString()) : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttachmentWidget(
                  InvenTreePartAttachment(),
                  part.pk,
                  InvenTreeAPI().checkPermission("part", "change"))
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
    fields["part"]["hidden"] = true;

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
      var response = await InvenTreeAPI().get("/api/part/${part.pk}/serial-numbers/", expectedStatusCode: null);
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

  List<Widget> actionTiles(BuildContext context) {
    List<Widget> tiles = [];

    tiles.add(headerTile());

    tiles.add(
      ListTile(
        title: Text(L10().stockItemCreate),
        leading: FaIcon(FontAwesomeIcons.box),
        onTap: () {
          _newStockItem(context);
        },
      )
    );

    if (InvenTreeAPI().supportModernBarcodes) {
      tiles.add(
        customBarcodeActionTile(context, part.customBarcode, "part", part.pk)
      );
    }

    return tiles;
  }

  int stockItemCount = 0;

  Widget getSelectedWidget(int index) {
    switch (index) {
      case 0:
        return Center(
          child: ListView(
            children: ListTile.divideTiles(
              context: context,
              tiles: partTiles()
            ).toList()
        ),
      );
      case 1:
        return PaginatedStockItemList(
          {"part": "${part.pk}"},
          true,
        );
      case 2:
        return Center(
          child: ListView(
            children: ListTile.divideTiles(
              context: context,
              tiles: actionTiles(context)
            ).toList()
          )
        );
      default:
        return Center();
    }
  }

  @override
  Widget getBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: tabIndex,
      onTap: onTabSelectionChanged,
      items: <BottomNavigationBarItem> [
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.infoCircle),
          label: L10().details,
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.boxes),
          label: L10().stock
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          label: L10().actions,
        ),
      ]
    );
  }

  @override
  Widget getBody(BuildContext context) {
    return getSelectedWidget(tabIndex);
  }
}
