/*
 * Base model for various "orders" which share common properties
 */


import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/part.dart";


/*
 * Generic class representing an "order"
 */
class InvenTreeOrder extends InvenTreeModel {

  InvenTreeOrder() : super();

  InvenTreeOrder.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  String get issueDate => getString("issue_date");

  String get completeDate => getString("complete_date");

  String get creationDate => getString("creation_date");

  String get targetDate => getString("target_date");

  int get lineItemCount => getInt("line_items", backup: 0);

  int get completedLineItemCount => getInt("completed_lines", backup: 0);

  bool get complete => completedLineItemCount >= lineItemCount;

  bool get overdue => getBool("overdue");

  String get reference => getString("reference");

  int get responsibleId => getInt("responsible");

  // Project code information
  int get projectCodeId => getInt("project_code");

  String get projectCode => getString("code", subKey: "project_code_detail");

  String get projectCodeDescription => getString("description", subKey: "project_code_detail");

  bool get hasProjectCode => projectCode.isNotEmpty;

  int get status => getInt("status");

  String get statusText => getString("status_text");

  double? get totalPrice {
    String price = getString("total_price");

    if (price.isEmpty) {
      return null;
    } else {
      return double.tryParse(price);
    }
  }

  // Return the currency for this order
  // Note that the nomenclature in the API changed at some point
  String get totalPriceCurrency {
    if (jsondata.containsKey("order_currency")) {
      return getString("order_currency");
    } else if (jsondata.containsKey("total_price_currency")) {
      return getString("total_price_currency");
    } else {
      return "";
    }
  }
}


/*
 * Generic class representing an "order line"
 */
class InvenTreeOrderLine extends InvenTreeModel {

  InvenTreeOrderLine() : super();

  InvenTreeOrderLine.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  bool get overdue => getBool("overdue");

  double get quantity => getDouble("quantity");

  String get reference => getString("reference");

  int get orderId => getInt("order");

  InvenTreePart? get part {
    dynamic part_detail = jsondata["part_detail"];

    if (part_detail == null) {
      return null;
    } else {
      return InvenTreePart.fromJson(part_detail as Map<String, dynamic>);
    }
  }

  int get partId => getInt("pk", subKey: "part_detail");

  String get partName => getString("name", subKey: "part_detail");

  String get partImage => getString("thumbnail", subKey: "part_detail");

  // TODO: Perhaps parse this as an actual date?
  String get targetDate => getString("target_date");
}