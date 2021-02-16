import 'dart:io';

import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/widget/part_notes.dart';
import 'package:InvenTree/widget/progress.dart';
import 'package:InvenTree/widget/snacks.dart';
import 'package:InvenTree/widget/stock_detail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/full_screen_image.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/refreshable_state.dart';


class PartDetailWidget extends StatefulWidget {

  PartDetailWidget(this.part, {Key key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartDisplayState createState() => _PartDisplayState(part);

}


class _PartDisplayState extends RefreshableState<PartDetailWidget> {

  final _editPartKey = GlobalKey<FormState>();

  @override
  String getAppBarTitle(BuildContext context) => I18N.of(context).partDetails;

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    return <Widget>[
      IconButton(
        icon: FaIcon(FontAwesomeIcons.globe),
        onPressed: _openInvenTreePage,
      ),
      // TODO: Hide the 'edit' button if the user does not have permission!!
      IconButton(
        icon: FaIcon(FontAwesomeIcons.edit),
        tooltip: I18N.of(context).edit,
        onPressed: _editPartDialog,
      )
    ];
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
    await part.getStockItems(context);
    await part.getTestTemplates(context);
  }

  void _toggleStar() async {
    await part.setStarred(context, !part.starred);
    refresh();
  }

  void _savePart(Map<String, String> values) async {

    final bool result = await part.update(context, values: values);

    showSnackIcon(
      result ? "Part edited" : "Part editing failed",
      success: result
    );

    refresh();
  }

  void _editPartDialog() {

    // Values which can be edited
    var _name;
    var _description;
    var _ipn;
    var _keywords;
    var _link;

    showFormDialog(I18N.of(context).editPart,
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
          label: I18N.of(context).name,
          initial: part.name,
          onSaved: (value) => _name = value,
        ),
        StringField(
          label: I18N.of(context).description,
          initial: part.description,
          onSaved: (value) => _description = value,
        ),
        StringField(
          label: I18N.of(context).internalPartNumber,
          initial: part.IPN,
          allowEmpty: true,
          onSaved: (value) => _ipn = value,
        ),
        StringField(
          label: I18N.of(context).keywords,
          initial: part.keywords,
          allowEmpty: true,
          onSaved: (value) => _keywords = value,
        ),
        StringField(
          label: I18N.of(context).link,
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
            icon: FaIcon(part.starred ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star),
            onPressed: null, // TODO: _toggleStar,
          ),
          leading: GestureDetector(
            child: InvenTreeAPI().getImage(part.thumbnail),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FullScreenWidget(part.fullname, part.image))
              );
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

    // Category information
    if (part.categoryName != null && part.categoryName.isNotEmpty) {
      tiles.add(
        ListTile(
            title: Text("Part Category"),
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
          title: Text("Part Category"),
          subtitle: Text("Top level part category"),
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
        title: Text(I18N.of(context).stock),
        leading: FaIcon(FontAwesomeIcons.boxes),
        trailing: Text("${part.inStockString}"),
        onTap: () {
          setState(() {
            tabIndex = 1;
          });
        },
      ),
    );

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
        title: Text("Bill of Materials"),
        leading: FaIcon(FontAwesomeIcons.thList),
        trailing: Text("${part.bomItemCount}"),
        onTap: null,
      )
      );

      tiles.add(
          ListTile(
            title: Text("Building"),
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
          title: Text("Required Tests"),
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
            title: Text("Notes"),
            leading: FaIcon(FontAwesomeIcons.stickyNote),
            trailing: Text(""),
            onTap: () {
              print("Hello");
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
          I18N.of(context).stockItems,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: part.stockItems.isEmpty ? Text("No stock items available") : null,
        trailing: part.stockItems.isNotEmpty ? Text("${part.stockItems.length}") : null,
      )
    );

    if (loading) {
      tiles.add(progressIndicator());
    } else if (part.stockItems.length > 0) {
      tiles.add(PartStockList(part.stockItems));
    }

    return tiles;
  }

  List<Widget> actionTiles() {
    List<Widget> tiles = [];

    tiles.add(headerTile());

    tiles.add(
      ListTile(
        title: Text(I18N.of(context).stockItemCreate),
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
        return Center(
          child: ListView(
            children: ListTile.divideTiles(
              context: context,
              tiles: stockTiles()
            ).toList()
          )
        );
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
          label: I18N.of(context).details,
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.boxes),
          label: I18N.of(context).stock
        ),
        // TODO - Add part actions
        /*
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.wrench),
          label: I18N.of(context).actions,
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

class PartStockList extends StatelessWidget {
  final List<InvenTreeStockItem> _items;

  PartStockList(this._items);

  void _openItem(BuildContext context, int pk) {
    // Load detail view for stock item
    InvenTreeStockItem().get(context, pk).then((var item) {
      if (item is InvenTreeStockItem) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StockDetailWidget(item)));
      }
    });
  }

  Widget _build(BuildContext context, int index) {

    InvenTreeStockItem item = _items[index];

    return ListTile(
      title: Text("${item.locationName}"),
      subtitle: Text("${item.locationPathString}"),
      trailing: Text(item.serialOrQuantityDisplay()),
      leading: FaIcon(FontAwesomeIcons.mapMarkerAlt),
      onTap: () {
        _openItem(context, item.pk);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemBuilder: _build,
        separatorBuilder: (_, __) => const Divider(height: 3),
        itemCount: _items.length
    );
  }
}