
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/category_display.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PartDisplayWidget extends StatefulWidget {

  PartDisplayWidget(this.part, {Key key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartDisplayState createState() => _PartDisplayState(part);

}


class _PartDisplayState extends State<PartDisplayWidget> {

  _PartDisplayState(this.part) {
    // TODO
  }

  InvenTreePart part;

  /*
   * Construct a list of detail elements about this part.
   * Not all elements are set for each part, so only add the ones that are important.
   */
  List<Widget> partDetails() {
    List<Widget> widgets = [

      // Image / name / description
      ListTile(
        title: Text("${part.fullname}"),
        subtitle: Text("${part.description}"),
        leading: Image(
            image: InvenTreeAPI().getImage(part.image)
        ),
        trailing: IconButton(
          icon:  FaIcon(FontAwesomeIcons.edit),
          onPressed: null,
        ),
      )
    ];

    return widgets;
  }

  /*
   * Build a list of tiles to display under the part description
   */
  List<Widget> partTiles() {

    List<Widget> tiles = [
      Card(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: partDetails(),
          )
      ),
    ];

    // Category information
    if (part.categoryName.isNotEmpty) {
      tiles.add(
        Card(
          child: ListTile(
            title: Text("${part.categoryName}"),
            leading: FaIcon(FontAwesomeIcons.stream),
            onTap: () {
              InvenTreePartCategory().get(part.categoryId).then((var cat) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDisplayWidget(cat)));
              });
            },
          )
        )
      );
    }

    // External link?
    if (part.link.isNotEmpty) {
      tiles.add(
        Card(
          child: ListTile(
            title: Text("${part.link}"),
            leading: FaIcon(FontAwesomeIcons.link),
          )
        )
      );
    }

    // Stock information
    tiles.add(
      Card(
        child: ListTile(
          title: Text("In Stock"),
          leading: FaIcon(FontAwesomeIcons.boxes),
          trailing: FlatButton(
              child: Text("${part.inStock}")
          ),
        )
      )
    );

    // Parts on order
    if (part.isPurchaseable) {
      tiles.add(
        Card(
          child: ListTile(
            title: Text("On Order"),
            leading: FaIcon(FontAwesomeIcons.shoppingCart),
            trailing: Text("${part.onOrder}"),
          )
        )
      );
    }

    // Parts being built
    if (part.isAssembly) {
      tiles.add(
        Card(
          child: ListTile(
            title: Text("Building"),
            leading: FaIcon(FontAwesomeIcons.tools),
            trailing: Text("${part.building}"),
          )
        )
      );
    }

    tiles.add(Spacer());

    return tiles;

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Part Details"),
      ),
      drawer: new InvenTreeDrawer(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: partTiles(),
        ),
      )
    );
  }
}