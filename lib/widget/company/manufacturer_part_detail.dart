import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/inventree/attachment.dart";
import "package:inventree/inventree/parameter.dart";

import "package:inventree/l10.dart";
import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";

import "package:inventree/inventree/company.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/widget/attachment_widget.dart";
import "package:inventree/widget/parameter_widget.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/progress.dart";

/*
 * Detail widget for viewing a single ManufacturerPart instance
 */
class ManufacturerPartDetailWidget extends StatefulWidget {
  const ManufacturerPartDetailWidget(this.manufacturerPart, {Key? key})
    : super(key: key);

  final InvenTreeManufacturerPart manufacturerPart;

  @override
  _ManufacturerPartDisplayState createState() =>
      _ManufacturerPartDisplayState();
}

class _ManufacturerPartDisplayState
    extends RefreshableState<ManufacturerPartDetailWidget> {
  _ManufacturerPartDisplayState();

  int parameterCount = 0;
  int attachmentCount = 0;

  @override
  String getAppBarTitle() => L10().manufacturerPart;

  @override
  Future<void> request(BuildContext context) async {
    final bool result =
        widget.manufacturerPart.pk > 0 &&
        await widget.manufacturerPart.reload();

    if (!result) {
      Navigator.of(context).pop();
      return;
    }

    InvenTreeParameter()
        .countParameters(
          InvenTreeManufacturerPart.MODEL_TYPE,
          widget.manufacturerPart.pk,
        )
        .then((value) {
          if (mounted) {
            setState(() {
              parameterCount = value;
            });
          }
        });

    InvenTreeAttachment()
        .countAttachments(
          InvenTreeManufacturerPart.MODEL_TYPE,
          widget.manufacturerPart.pk,
        )
        .then((value) {
          if (mounted) {
            setState(() {
              attachmentCount = value;
            });
          }
        });
  }

  Future<void> editManufacturerPart(BuildContext context) async {
    widget.manufacturerPart.editForm(
      context,
      L10().manufacturerPartEdit,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().itemUpdated, success: true);
      },
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    // TODO: Barcode actions?

    return actions;
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.manufacturerPart.canEdit) {
      actions.add(
        IconButton(
          icon: Icon(TablerIcons.edit),
          tooltip: L10().edit,
          onPressed: () {
            editManufacturerPart(context);
          },
        ),
      );
    }

    return actions;
  }

  /*
   * Build a set of tiles to display for this ManufacturerPart instance
   */
  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    // Internal Part
    tiles.add(
      ListTile(
        title: Text(L10().internalPart),
        subtitle: Text(widget.manufacturerPart.partName),
        leading: Icon(TablerIcons.box, color: COLOR_ACTION),
        trailing: InvenTreeAPI().getThumbnail(
          widget.manufacturerPart.partImage,
        ),
        onTap: () async {
          showLoadingOverlay();
          final part = await InvenTreePart().get(
            widget.manufacturerPart.partId,
          );
          hideLoadingOverlay();

          if (part is InvenTreePart) {
            part.goToDetailPage(context);
          }
        },
      ),
    );

    // Manufacturer details
    tiles.add(
      ListTile(
        title: Text(L10().manufacturer),
        subtitle: Text(widget.manufacturerPart.manufacturerName),
        leading: Icon(TablerIcons.building_factory_2, color: COLOR_ACTION),
        trailing: InvenTreeAPI().getThumbnail(
          widget.manufacturerPart.manufacturerImage,
        ),
        onTap: () async {
          showLoadingOverlay();
          var supplier = await InvenTreeCompany().get(
            widget.manufacturerPart.manufacturerId,
          );
          hideLoadingOverlay();

          if (supplier is InvenTreeCompany) {
            supplier.goToDetailPage(context);
          }
        },
      ),
    );

    // MPN (part number)
    tiles.add(
      ListTile(
        title: Text(L10().manufacturerPartNumber),
        subtitle: Text(widget.manufacturerPart.MPN),
        leading: Icon(TablerIcons.hash),
      ),
    );

    // Description
    if (widget.manufacturerPart.description.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().description),
          subtitle: Text(widget.manufacturerPart.description),
          leading: Icon(TablerIcons.info_circle),
        ),
      );
    }

    if (widget.manufacturerPart.hasLink) {
      tiles.add(
        ListTile(
          title: Text(widget.manufacturerPart.link),
          leading: Icon(TablerIcons.link, color: COLOR_ACTION),
          onTap: () async {
            widget.manufacturerPart.openLink();
          },
        ),
      );
    }

    ListTile? parameterTile = ShowParametersItem(
      context,
      InvenTreeManufacturerPart.MODEL_TYPE,
      widget.manufacturerPart.pk,
      parameterCount,
      widget.manufacturerPart.canEdit,
    );

    if (parameterTile != null) {
      tiles.add(parameterTile);
    }

    ListTile? attachmentTile = ShowAttachmentsItem(
      context,
      InvenTreeManufacturerPart.MODEL_TYPE,
      widget.manufacturerPart.pk,
      widget.manufacturerPart.MPN,
      attachmentCount,
      widget.manufacturerPart.canEdit,
    );

    if (attachmentTile != null) {
      tiles.add(attachmentTile);
    }

    return tiles;
  }
}
