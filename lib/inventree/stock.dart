import 'model.dart';


class InvenTreeStockItem extends InvenTreeModel {
  @override
  String URL = "stock/";

  InvenTreeStockItem() : super();

  InvenTreeStockItem.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    // TODO
  }

  String get partName => jsondata['part_name'] as String ?? '';

  double get quantity => jsondata['quantity'] as double ?? 0.0;

  int get locationId => jsondata['location'] as int ?? -1;

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

  @override
  bool matchAgainstString(String filter) {

    if (name.toLowerCase().contains(filter)) return true;

    if (description.toLowerCase().contains(filter)) return true;

    return false;
  }
}