
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";

/*
 * Class representing the BomItem database model
 */
class InvenTreeBomItem extends InvenTreeModel {

  InvenTreeBomItem() : super();

  InvenTreeBomItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeModel createFromJson(Map<String, dynamic> json) => InvenTreeBomItem.fromJson(json);

  @override
  String get URL => "bom/";

  @override
  Map<String, String> defaultListFilters() {
    return {
      "sub_part_detail": "true",
      "part_detail": "true",
      "show_pricing": "false",
    };
  }

  @override
  Map<String, String> defaultGetFilters() {
    return {
      "sub_part_detail": "true",
    };
  }

  // Extract the 'reference' value associated with this BomItem
  String get reference => getString("reference");
  
  // Extract the 'quantity' value associated with this BomItem
  double get quantity => getDouble("quantity");

  // Extract the ID of the related part
  int get partId => getInt("part");

  // Return a Part instance for the referenced part
  InvenTreePart? get part {
    if (jsondata.containsKey("part_detail")) {
      dynamic data = jsondata["part_detail"] ?? {};
      if (data is Map<String, dynamic>) {
        return InvenTreePart.fromJson(data);
      }
    }

    return null;
  }

  // Return a Part instance for the referenced sub-part
  InvenTreePart? get subPart {
    if (jsondata.containsKey("sub_part_detail")) {
      dynamic data = jsondata["sub_part_detail"] ?? {};
      if (data is Map<String, dynamic>) {
        return InvenTreePart.fromJson(data);
      }
    }

    return null;
}

  // Extract the ID of the related sub-part
  int get subPartId => getInt("sub_part");
}