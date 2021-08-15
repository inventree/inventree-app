

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/widget/refreshable_state.dart';

import '../api.dart';
import '../l10.dart';

class PartAttachmentsWidget extends StatefulWidget {

  PartAttachmentsWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartAttachmentDisplayState createState() => _PartAttachmentDisplayState(part);
}


class _PartAttachmentDisplayState extends RefreshableState<PartAttachmentsWidget> {

  _PartAttachmentDisplayState(this.part);

  final InvenTreePart part;

  @override
  String getAppBarTitle(BuildContext context) => L10().attachments;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (false && InvenTreeAPI().checkPermission('part', 'change')) {
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.plus),
          onPressed: null,
        )
      );
    }

    return actions;
  }

  @override
  Future<void> request() async {
    // TODO - Request part attachments from the server
  }

  @override
  Widget getBody(BuildContext context) {
    return Center(
      child: ListView(
        children: ListTile.divideTiles(
          context: context,
          tiles: attachmentTiles(context)
        ).toList(),
      )
    );
  }


  List<Widget> attachmentTiles(BuildContext context) {

    List<Widget> tiles = [];

    return tiles;

  }

}