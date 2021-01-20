
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:InvenTree/widget/dialogs.dart';
import 'package:InvenTree/widget/fields.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PartDetailWidget extends StatefulWidget {

  PartDetailWidget(this.part, {Key key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartDisplayState createState() => _PartDisplayState(part);

}


class _PartDisplayState extends RefreshableState<PartDetailWidget> {

  final _editPartKey = GlobalKey<FormState>();

  @override
  String getAppBarTitle(BuildContext context) { return "Part"; }

  _PartDisplayState(this.part) {
    // TODO
  }

  InvenTreePart part;

  int _tabIndex = 0;

  @override
  Future<void> request(BuildContext context) async {
    await part.reload(context);
    await part.getTestTemplates(context);
  }

  void _savePart(Map<String, String> values) async {

    Navigator.of(context).pop();

    var response = await part.update(context, values: values);

    refresh();
  }

  void _editPartDialog() {

    // Values which can be edited
    var _name;
    var _description;
    var _ipn;
    var _revision;

    showFormDialog(context, "Edit Part",
      key: _editPartKey,
      actions: <Widget>[
        FlatButton(
          child: Text("Cancel"),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        FlatButton(
          child: Text("Save"),
          onPressed: () {
            if (_editPartKey.currentState.validate()) {
              _editPartKey.currentState.save();

              _savePart({
                "name": _name,
                "description": _description,
                "IPN": _ipn,
              });
            }
          },
        ),
      ],
      fields: <Widget>[
        StringField(
          label: "Part Name",
          initial: part.name,
          onSaved: (value) => _name = value,
        ),
        StringField(
          label: "Part Description",
          initial: part.description,
          onSaved: (value) => _description = value,
        ),
        StringField(
          label: "Internal Part Number",
          initial: part.IPN,
          onSaved: (value) => _ipn = value,
        )

      ]
    );

  }

  /*
   * Build a list of tiles to display under the part description
   */
  List<Widget> partTiles() {

    List<Widget> tiles = [];

    // Image / name / description
    tiles.add(
      Card(
        child: ListTile(
          title: Text("${part.fullname}"),
          subtitle: Text("${part.description}"),
          leading: InvenTreeAPI().getImage(part.image),
          trailing: IconButton(
            icon: FaIcon(FontAwesomeIcons.edit),
            onPressed: _editPartDialog,
          ),
        )
      )
    );

    // Category information
    if (part.categoryName != null && part.categoryName.isNotEmpty) {
      tiles.add(
        ListTile(
            title: Text("Part Category"),
            subtitle: Text("${part.categoryName}"),
            leading: FaIcon(FontAwesomeIcons.stream),
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
          subtitle: Text("No category set"),
          leading: FaIcon(FontAwesomeIcons.stream),
        )
      );
    }

    // External link?
    if (part.link.isNotEmpty) {
      tiles.add(
        ListTile(
            title: Text("${part.link}"),
            leading: FaIcon(FontAwesomeIcons.link),
            trailing: Text(""),
            onTap: null,
          )
      );
    }

    // Stock information
    tiles.add(
        ListTile(
          title: Text("Stock"),
          leading: FaIcon(FontAwesomeIcons.boxes),
          trailing: Text("${part.inStock}"),
          onTap: null,
        ),
    );

    // Parts on order
    if (part.isPurchaseable) {
      tiles.add(
        ListTile(
            title: Text("On Order"),
            leading: FaIcon(FontAwesomeIcons.shoppingCart),
            trailing: Text("${part.onOrder}"),
            onTap: null,
          )
      );
    }

    // Parts being built
    if (part.isAssembly) {

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

    if (part.isComponent) {
      tiles.add(ListTile(
            title: Text("Used In"),
            leading: FaIcon(FontAwesomeIcons.sitemap),
            trailing: Text("${part.usedInCount}"),
            onTap: null,
          )
      );
    }

    if (part.isTrackable) {
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
            onTap: null,
          )
      );
    }

    return tiles;

  }

  void _onTabSelectionChanged(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  Widget getSelectedWidget(int index) {
    switch (index) {
      case 0:
        return Center(
          child: ListView(
          children: partTiles(),
        ),
      );
      case 1:
        return Center(
          child: ListView(
            children: <Widget>[
              ListTile(
                title: Text("Stock"),
                subtitle: Text("Stock info goes here!"),
              )
            ],
          )
        );
      default:
        return null;
    }
  }

  @override
  Widget getBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _tabIndex,
      onTap: _onTabSelectionChanged,
      items: const <BottomNavigationBarItem> [
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.infoCircle),
          title: Text("Details"),
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.thList),
          title: Text("BOM"),
        ),
        BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.boxes),
          title: Text("Stock"),
        ),
      ]
    );
  }

  @override
  Widget getBody(BuildContext context) {
    return getSelectedWidget(_tabIndex);
  }
}