import "package:inventree/inventree/model.dart";

/*
 * Class representing a "notification"
 */

class InvenTreeNotification extends InvenTreeModel {

  InvenTreeNotification() : super();

  InvenTreeNotification.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeNotification createFromJson(Map<String, dynamic> json) {
    return InvenTreeNotification.fromJson(json);
  }

  @override
  String get URL => "notifications/";

  @override
  Map<String, String> defaultListFilters() {

    // By default, only return 'unread' notifications
    return {
      "read": "false",
    };
  }

  String get message => (jsondata["message"] ?? "") as String;

  DateTime? get creationDate {
    if (jsondata.containsKey("creation")) {
      return DateTime.tryParse((jsondata["creation"] ?? "") as String);
    } else {
      return null;
    }
  }

  /*
   * Dismiss this notification (mark as read)
   */
  Future<void> dismiss() async {

    if (api.apiVersion >= 82) {
      // "Modern" API endpoint operates a little differently
      await update(values: {"read": "true"});
    } else {
      await api.post("${url}read/");
    }
  }

}