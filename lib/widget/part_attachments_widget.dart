

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/widget/refreshable_state.dart';
import 'package:inventree/widget/snacks.dart';

import 'dart:io';

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

  List<InvenTreePartAttachment> attachments = [];

  @override
  String getAppBarTitle(BuildContext context) => L10().attachments;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission('part', 'change')) {

      // File upload
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.fileUpload),
          onPressed: uploadFile,
        )
      );

      // Upload from camera
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.camera),
          onPressed: uploadFromCamera,
        )
      );
    }

    return actions;
  }

  Future<void> upload(File file) async {
    final bool result = await InvenTreePartAttachment().uploadAttachment(
      file,
      fields: {
        "part": "${part.pk}"
      }
    );

    if (result) {
      showSnackIcon(L10().uploadSuccess, success: true);
    } else {
      showSnackIcon(L10().uploadFailed, success: false);
    }

    refresh();

  }

  /*
   * Select a file from the device to upload
   */
  Future<void> uploadFile() async {

    final FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {

      String? path = result.files.single.path;

      if (path != null) {
        File attachment = File(path);

        upload(attachment);
      }
    }

  }

  /*
   * Upload an attachment by taking a new picture with the built in device camera
   */
  Future<void> uploadFromCamera() async {


    final picker = ImagePicker();

    final pickedImage = await picker.getImage(source: ImageSource.camera);

    if (pickedImage != null) {
      File? attachment = File(pickedImage.path);
      upload(attachment);
    }

    refresh();
  }

  @override
  Future<void> request() async {

    await InvenTreePartAttachment().list(
      filters: {
        "part": "${part.pk}"
      }
    ).then((var results) {

      attachments.clear();

      for (var result in results) {
        if (result is InvenTreePartAttachment) {
          attachments.add(result);
        }
      }
    });

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

    for (var attachment in attachments) {
      tiles.add(ListTile(
        title: Text(attachment.filename),
        subtitle: Text(attachment.comment),
        leading: FaIcon(attachment.icon),
        onTap: () async {
          await attachment.downloadAttachment();
        },
      ));
    }

    if (tiles.length == 0) {
      tiles.add(ListTile(
        title: Text(L10().attachmentNone),
        subtitle: Text(
            L10().attachmentNonePartDetail,
            style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ));
    }

    return tiles;

  }

}