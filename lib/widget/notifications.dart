
import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/l10.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/notification.dart";
import "package:inventree/widget/refreshable_state.dart";


class NotificationWidget extends StatefulWidget {

  @override
  _NotificationState createState() => _NotificationState();

}


class _NotificationState extends RefreshableState<NotificationWidget> {

  _NotificationState() : super();

  List<InvenTreeNotification> notifications = [];

  bool isDismissing = false;

  @override
  String getAppBarTitle() => L10().notifications;

  @override
  Future<void> request (BuildContext context) async {

    final results = await InvenTreeNotification().list();

    notifications.clear();

    for (InvenTreeModel n in results) {
      if (n is InvenTreeNotification) {
        notifications.add(n);
      }
    }
  }

  /*
   * Dismiss an individual notification entry (mark it as "read")
   */
  Future<void> dismissNotification(BuildContext context, InvenTreeNotification notification) async {

    if (mounted) {
      setState(() {
        isDismissing = true;
      });
    } else {
      return;
    }

    await notification.dismiss();

    if (mounted) {
      refresh(context);

      setState(() {
        isDismissing = false;
      });
    }
  }

  /*
   * Display an individual notification message
   */
  @override
  List<Widget> getTiles(BuildContext context) {

    List<Widget> tiles = [];

    tiles.add(
      ListTile(
        title: Text(
          L10().notifications,
        ),
        subtitle: notifications.isEmpty ? Text(L10().notificationsEmpty) : null,
        leading: notifications.isEmpty ? FaIcon(FontAwesomeIcons.bellSlash) : FaIcon(FontAwesomeIcons.bell),
        trailing: Text("${notifications.length}"),
      )
    );

    for (var notification in notifications) {
      tiles.add(
        ListTile(
          title: Text(notification.name),
          subtitle: Text(notification.message),
          trailing: IconButton(
            icon: FaIcon(FontAwesomeIcons.bookmark),
            onPressed: isDismissing ? null : () async {
              dismissNotification(context, notification);
            },
          ),
        )
      );
    }

    return tiles;

  }
}
