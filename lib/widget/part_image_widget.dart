import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:inventree/api.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/inventree/part.dart';
import 'package:inventree/widget/refreshable_state.dart';

class PartImageWidget extends StatefulWidget {

  PartImageWidget(this.part, {Key? key}) : super(key: key);

  final InvenTreePart part;

  @override
  _PartImageState createState() => _PartImageState(part);

}


class _PartImageState extends RefreshableState<PartImageWidget> {

  _PartImageState(this.part);

  final InvenTreePart part;

  @override
  Future<void> request() async {
    await part.reload();
  }

  void uploadFromGallery() async {

    final picker = ImagePicker();

    final pickedImage = await picker.getImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      File? img = File(pickedImage.path);

      await part.uploadImage(img);

      refresh();
    }
  }

  void uploadFromCamera() async {

    final picker = ImagePicker();

    final pickedImage = await picker.getImage(source: ImageSource.camera);

    if (pickedImage != null) {
      File? img = File(pickedImage.path);

      await part.uploadImage(img);

      refresh();
    }

  }

  @override
  String getAppBarTitle(BuildContext context) => part.fullname;

  @override
  List<Widget> getAppBarActions(BuildContext context) {

    List<Widget> actions = [];

    if (InvenTreeAPI().checkPermission('part', 'change')) {

      // File upload
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.fileImage),
          onPressed: uploadFromGallery,
        )
      );

      // Camera upload
      actions.add(
        IconButton(
          icon: FaIcon(FontAwesomeIcons.camera),
          onPressed: uploadFromCamera,
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