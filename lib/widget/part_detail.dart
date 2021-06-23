import 'dart:io';

import 'package:InvenTree/widget/part_notes.dart';
import 'package:InvenTree/widget/progress.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:InvenTree/l10.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/full_screen_image.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/refreshable_state.dart';

import 'location_display.dart';


class PartDetailWidget extends StatefulWidget {

  PartDetailWidget(this.part, {Key key}) : super(key: key);

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
          onPressed: _editPartDialog,
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
  Future<void> request(BuildContext context) async {
    await part.reload(context);
    await part.getTestTemplates(context);
  }

  void _toggleStar() async {

    if (InvenTreeAPI().checkPermission('part', 'change')) {
      await part.update(context, values: {"starred": "${!part.starred}"});
      refresh();
    }
  }

  void _savePart(Map<String, String> values) async {

    final bool result = await part.update(context, values: values);

    if (result) {
      showSnackIcon("Part edited", success: true);
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
  void _uploadImage(File image) async {

    final result = await part.uploadImage(image);

    if (result) {
      showSnackIcon(
        L10().imageUploadSuccess,
        success: true
      );
    } else {
      showSnackIcon(
        L10().imageUploadFailure,
        success: false,
      );
    }

    refresh();
  }

  void _selectImage() {

    File _attachment;

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

  void _editPartDialog() {

    // Values which can be edited
    var _name;
    var _description;
    var _ipn;
    var _keywords;
    var _link;

    showFormDialog(L10().editPart,
      key: _editPartKey,
      callback: () {
        _savePart({
          "name": _name,
          "description": _description,
          "IPN": _ipn,
          "keywords": _keywords,
          "link": _link
        });
      },
      fields: <Widget>[
        StringField(
          label: L10().name,
          initial: part.name,
          onSaved: (value) => _name = value,
        ),
        StringField(
          label: L10().description,
          initial: part.description,
          onSaved: (value) => _description = value,
        ),
        StringField(
          label: L10().internalPartNumber,
          initial: part.IPN,
          allowEmpty: true,
          onSaved: (value) => _ipn = value,
        ),
        StringField(
          label: L10().keywords,
          initial: part.keywords,
          allowEmpty: true,
          onSaved: (value) => _keywords = value,
        ),
        StringField(
          label: L10().link,
          initial: part.link,
          allowEmpty: true,
          onSaved: (value) => _link = value
        )
      ]
    );

  }

  Widget headerTile() {
    return Card(
        child: ListTile(
          title: Text("${part.fullname}"),
          subtitle: Text("${part.description}"),
          trailing: IconButton(
            icon: FaIcon(part.starred ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star,
              color: part.starred ? Color.fromRGBO(250, 250, 100, 1) : null,
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

    // Category information
    if (part.categoryName != null && part.categoryName.isNotEmpty) {
      tiles.add(
        ListTile(
            title: Text(L10().partCategory),
            subtitle: Text("${part.categoryName}"),
            leading: FaIcon(FontAwesomeIcons.sitemap),
            onTap: () {
              if (part.categoryId > 0) {
                InvenTreePartCategory().get(context, part.categoryId).then((var cat) {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CategoryDisplayWidget(cat)));
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
          leading: FaIcon(FontAwesomeIcons.sitemap),
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
        leading: FaIcon(FontAwesomeIcons.boxes),
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
            leading: FaIcon(FontAwesomeIcons.link),
            trailing: FaIcon(FontAwesomeIcons.externalLinkAlt),
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
            leading: FaIcon(FontAwesomeIcons.stickyNote),
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
        subtitle: part.stockItems.isEmpty ? Text("No stock items available") : null,
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
        title: Text("Scan New Stock Item"),
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
        return null;
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