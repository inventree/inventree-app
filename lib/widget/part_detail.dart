import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/app_colors.dart';

import 'package:inventree/l10.dart';
import 'package:inventree/api_form.dart';
import 'package:inventree/widget/part_notes.dart';
import 'package:inventree/widget/progress.dart';
import 'package:inventree/widget/snacks.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/widget/full_screen_image.dart';
import 'package:inventree/widget/category_display.dart';
import 'package:inventree/widget/dialogs.dart';
import 'package:inventree/widget/fields.dart';
import 'package:inventree/api.dart';
import 'package:inventree/widget/refreshable_state.dart';

import 'location_display.dart';


class PartDetailWidget extends StatefulWidget {

  PartDetailWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartDisplayState createState() => _PartDisplayState(part);

}


class _PartDisplayState extends RefreshableState<PartDetailWidget> {

  final _editImageKey = GlobalKey<FormState>();
  final _editPartKey = GlobalKey<FormState>();

  @override
  String getAppBarTitle(BuildContext context) => L10().partDetails;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission('part', 'view')) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.globe),
          onPressed: _openInvenTreePage,
        ),
      );
    }

    if (InvenTreeAPI().checkPermission('part', 'change')) {
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

  _PartDisplayState(this.part) {
    // TODO
  }

  Future<void> _openInvenTreePage() async {
    part.goToInvenTreePage();
  }

  InvenTreePart part;

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

  void _toggleStar() async {

    if (InvenTreeAPI().checkPermission('part', 'view')) {
      await part.update(values: {"starred": "${!part.starred}"});
      refresh();
    }
  }

  void _savePart(Map<String, String> values) async {

    final bool result = await part.update(values: values);

    if (result) {
      showSnackIcon(L10().partEdited, success: true);
    }
    /*
    showSnackIcon(
      result ? "Part edited" : "Part editing failed",
      success: result
    );
    */

    refresh();
  }

  /**
   * Upload image for this Part.
   * Show a SnackBar with upload result.
   */
  void _uploadImage(File? image) async {

    if (image == null) {
      return;
    }

    final result = await part.uploadImage(image);

    if (result) {
      showSnackIcon(
        L10().imageUploadSuccess,
        success: true
      );

      refresh();

    } else {
      showSnackIcon(
        L10().imageUploadFailure,
        success: false,
      );
    }
  }

  void _selectImage() {

    File? _attachment;

    if (!InvenTreeAPI().checkPermission('part', 'change')) {
      return;
    }

    showFormDialog(L10().selectImage,
      key: _editImageKey,
      callback: () {
        _uploadImage(_attachment);
      },
      fields: <Widget>[
        ImagePickerField(
          context,
          label: L10().attachImage,
          required: true,
          onSaved: (attachment) => _attachment = attachment,
        ),
      ]
    );
  }

  void _editPartDialog(BuildContext context) {

    launchApiForm(
        context,
        L10().editPart,
        part.url,
        {
          "name": {},
          "description": {},
          "IPN": {},
          "revision": {},
          "keywords": {},
          "link": {},

          "category": {
          },

          // Checkbox fields
          "active": {},
          "assembly": {},
          "component": {},
          "purchaseable": {},
          "salable": {},
          "trackable": {},
          "is_template": {},
          "virtual": {},
        },
        modelData: part.jsondata,
        onSuccess: refresh,
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
                MaterialPageRoute(builder: (context) => FullScreenWidget(part.fullname, part.image))
              );
            }),
            onLongPress: _selectImage,
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
        leading: FaIcon(FontAwesomeIcons.boxes, color: COLOR_CLICK),
        trailing: Text("${part.inStockString}"),
        onTap: () {
          setState(() {
            tabIndex = 1;
          });
        },
      ),
    );

    if (false && part.isPurchaseable) {

      if (part.supplier_count > 0) {
        tiles.add(
          ListTile(
            title: Text(L10().suppliers),
            leading: FaIcon(FontAwesomeIcons.industry),
            trailing: Text("${part.supplier_count}"),
          )
        );
      }
    }

    // TODO - Add link to parts on order
    // Parts on order
    if (false && part.isPurchaseable) {
      tiles.add(
          ListTile(
            title: Text("On Order"),
            leading: FaIcon(FontAwesomeIcons.shoppingCart),
            trailing: Text("${part.onOrder}"),
            onTap: () {
              // TODO: Click through to show items on order
            },
          )
      );
    }

    // TODO
    // Parts being built
    if (false && part.isAssembly) {

      tiles.add(ListTile(
        title: Text(L10().billOfMaterials),
        leading: FaIcon(FontAwesomeIcons.thList),
        trailing: Text("${part.bomItemCount}"),
        onTap: null,
      )
      );

      tiles.add(
          ListTile(
            title: Text(L10().building),
            leading: FaIcon(FontAwesomeIcons.tools),
            trailing: Text("${part.building}"),
            onTap: null,
          )
      );
    }

    // TODO - Do we want to use the app to display "used in"?
    if (false && part.isComponent) {
      tiles.add(ListTile(
        title: Text("Used In"),
        leading: FaIcon(FontAwesomeIcons.sitemap),
        trailing: Text("${part.usedInCount}"),
        onTap: null,
      )
      );
    }

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

    // TODO - Add request tests?
    if (false && part.isTrackable) {
      tiles.add(ListTile(
          title: Text(L10().testsRequired),
          leading: FaIcon(FontAwesomeIcons.tasks),
          trailing: Text("${part.testTemplateCount}"),
          onTap: null,
        )
      );
    }

    // Notes field?
    if (part.notes.isNotEmpty) {
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
    }

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

    /*
    if (loading) {
      tiles.add(progressIndicator());
    } else if (part.stockItems.length > 0) {
      tiles.add(PartStockList(part.stockItems));
    }
    */

    return tiles;
  }

  List<Widget> actionTiles() {
    List<Widget> tiles = [];

    tiles.add(headerTile());

    tiles.add(
      ListTile(
        title: Text(L10().stockItemCreate),
        leading: FaIcon(FontAwesomeIcons.box),
        onTap: null,
      )
    );

    tiles.add(
      ListTile(
        title: Text(L10().barcodeScanItem),
        leading: FaIcon(FontAwesomeIcons.box),
        trailing: FaIcon(FontAwesomeIcons.qrcode),
        onTap: null,
      ),
    );

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
        return PaginatedStockList({"part": "${part.pk}"});
      case 2:
        return Center(
          child: ListView(
            children: ListTile.divideTiles(
              context: context,
              tiles: actionTiles()
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
        /*
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          label: L10().actions,
        ),
         */
      ]
    );
  }

  @override
  Widget getBody(BuildContext context) {
    return getSelectedWidget(tabIndex);
  }
}
