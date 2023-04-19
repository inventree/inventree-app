import "dart:io";

import "package:flutter/material.dart";

import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/l10.dart";

class PartImageWidget extends StatefulWidget {

  const PartImageWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartImageState createState() => _PartImageState(part);

}


class _PartImageState extends RefreshableState<PartImageWidget> {

  _PartImageState(this.part);

  final InvenTreePart part;

  @override
  Future<void> request(BuildContext context) async {
    await part.reload();
  }

  @override
  String getAppBarTitle() => part.fullname;

  @override
  List<Widget> appBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (part.canEdit) {

      // File upload
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.fileArrowUp),
          onPressed: () async {

            FilePickerDialog.pickFile(
              onPicked: (File file) async {
                final result = await part.uploadImage(file);

                if (!result) {
                  showSnackIcon(L10().uploadFailed, success: false);
                }

                refresh(context);
              }
            );

          },
        )
      );
    }

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return InvenTreeAPI().getImage(part.image);
  }

}