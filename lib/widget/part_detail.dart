
import "package:flutter/cupertino.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/stock.dart";

import "package:inventree/l10.dart";
import "package:inventree/widget/part_attachments_widget.dart";
import "package:inventree/widget/part_notes.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/category_display.dart";
import "package:inventree/api.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/part_image_widget.dart";
import "package:inventree/widget/stock_detail.dart";

import "package:inventree/widget/location_display.dart";
import 'package:inventree/widget/stock_list.dart';


class PartDetailWidget extends StatefulWidget {

  const PartDetailWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartDisplayState createState() => _PartDisplayState(part);

}


class _PartDisplayState extends RefreshableState<PartDetailWidget> {

  _PartDisplayState(this.part);

  InvenTreePart part;

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
    refresh();

    setState(() {

    });
  }

  @override
  Future<void> request() async {
    await part.reload();
    await part.getTestTemplates();
  }

  Future <void> _toggleStar() async {

    if (InvenTreeAPI().checkPermission("part", "view")) {
      await part.update(values: {"starred": "${!part.starred}"});
      refresh();
    }
  }

  void _editPartDialog(BuildContext context) {

    part.editForm(
      context,
      L10().editPart,
      onSuccess: (data) async {
        refresh();
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
            onPressed: _toggleStar,
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
                refresh();
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

    // Category information
    if (part.categoryName.isNotEmpty) {
      tiles.add(
        ListTile(
            title: Text(L10().partCategory),
            subtitle: Text("${part.categoryName}"),
            leading: FaIcon(FontAwesomeIcons.sitemap, color: COLOR_CLICK),
            onTap: () {
              if (part.categoryId > 0) {
                InvenTreePartCategory().get(part.categoryId).then((var cat) {

                  if (cat is InvenTreePartCategory) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => CategoryDisplayWidget(cat)));
                  }
                });
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(null)));
          },
        )
      );
    }

    // Stock information
    tiles.add(
      ListTile(
        title: Text(L10().stock),
        subtitle: Text(L10().stockDetails),
        leading: FaIcon(FontAwesomeIcons.boxes, color: COLOR_CLICK),
        trailing: Text("${part.inStockString}"),
        onTap: () {
          setState(() {
            tabIndex = 1;
          });
        },
      ),
    );

    // Keywords?
    if (part.keywords.isNotEmpty) {
      tiles.add(
          ListTile(
            title: Text("${part.keywords}"),
            leading: FaIcon(FontAwesomeIcons.key),
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

    // Tiles for "purchaseable" parts
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

      if (part.bomItemCount > 0) {
        tiles.add(
            ListTile(
                title: Text(L10().billOfMaterials),
                leading: FaIcon(FontAwesomeIcons.thList),
                trailing: Text("${part.bomItemCount}"),
                onTap: () {
                  // TODO
                }
            )
        );
      }

      if (part.building > 0) {
        tiles.add(
            ListTile(
              title: Text(L10().building),
              leading: FaIcon(FontAwesomeIcons.tools),
              trailing: Text("${part.building}"),
              onTap: () {
                // TODO
              },
            )
        );
      }
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

    // TODO - Add request tests?
    /*
    if (part.isTrackable) {
      tiles.add(ListTile(
          title: Text(L10().testsRequired),
          leading: FaIcon(FontAwesomeIcons.tasks),
          trailing: Text("${part.testTemplateCount}"),
          onTap: null,
        )
      );
    }
     */

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
        trailing: Text(""),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PartAttachmentsWidget(part)
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

  Future<void> _newStockItem(BuildContext context) async {

    var fields = InvenTreeStockItem().formFields();

    fields["part"]["hidden"] = true;

    int? default_location = part.defaultLocation;

    if (default_location != null) {
      fields["location"]["value"] = default_location;
    }

    InvenTreeStockItem().createForm(
        context,
        L10().stockItemCreate,
        fields: fields,
        data: {
          "part": "${part.pk}",
        },
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

    // TODO - Add this action back in once implemented
    /*
    tiles.add(
      ListTile(
        title: Text(L10().barcodeScanItem),
        leading: FaIcon(FontAwesomeIcons.box),
        trailing: FaIcon(FontAwesomeIcons.qrcode),
        onTap: () {
          // TODO
        },
      ),
    );
    */

    /*
    // TODO: Implement part deletion
    if (!part.isActive && InvenTreeAPI().checkPermission("part", "delete")) {
      tiles.add(
        ListTile(
          title: Text(L10().deletePart),
          subtitle: Text(L10().deletePartDetail),
          leading: FaIcon(FontAwesomeIcons.trashAlt, color: COLOR_DANGER),
          onTap: () {
            // TODO
          },
        )
      );
    }
     */

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
          {"part": "${part.pk}"}
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
        // TODO - Add part actions
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
