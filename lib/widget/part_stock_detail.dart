// Flutter packages
import 'package:InvenTree/inventree/stock.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// InvenTree packages
import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/part.dart';
import 'package:InvenTree/widget/stock_detail.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PartStockDetailWidget extends StatefulWidget {
  /*
   * The PartStockDetail widget displays all "in stock" instances for a given Part
   */

  PartStockDetailWidget(this.part, {Key key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartStockDisplayState createState() => _PartStockDisplayState(part);
}


class _PartStockDisplayState extends RefreshableState<PartStockDetailWidget> {

  @override
  String getAppBarTitle(BuildContext context) => I18N.of(context).partStock;

  _PartStockDisplayState(this.part) {
    // TODO
  }

  InvenTreePart part;

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh();
    print("onBuild");
  }

  @override
  Future<void> request(BuildContext context) async {
    await part.reload(context);
    await part.getStockItems(context);

    setState(() {
    });
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: <Widget>[
        Card(
          child: ListTile(
            title: Text(part.fullname),
            subtitle: Text(part.description),
            leading: InvenTreeAPI().getImage(part.thumbnail),
            trailing: Text('${part.inStock}'),
          )
        ),
        PartStockList(part.stockItems),
      ]
    );
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
    return ListView.builder(
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      itemBuilder: _build,
      itemCount: _items.length
    );
  }
}