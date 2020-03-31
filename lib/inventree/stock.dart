import 'model.dart';


class InvenTreeStockItem extends InvenTreeModel {
  @override
  String URL = "stock/";

  InvenTreeStockItem() : super();

  InvenTreeStockItem.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {
    var item = InvenTreeStockItem.fromJson(json);

    // TODO?

    return item;
  }
}


class InvenTreeStockLocation extends InvenTreeModel {
  @override
  String URL = "stock/location/";

  InvenTreeStockLocation() : super();

  InvenTreeStockLocation.fromJson(Map<String, dynamic> json) : super.fromJson(json) {

  }

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) {

    var loc = InvenTreeStockLocation.fromJson(json);

    return loc;

  }
}