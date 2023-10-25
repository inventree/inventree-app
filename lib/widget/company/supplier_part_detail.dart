import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/company.dart";

import "package:inventree/widget/company/company_detail.dart";
import "package:inventree/widget/part/part_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:url_launcher/url_launcher.dart";


/*
 * Detail widget for viewing a single SupplierPart instance
 */
class SupplierPartDetailWidget extends StatefulWidget {

  const SupplierPartDetailWidget(this.supplierPart, {Key? key}) : super(key: key);

  final InvenTreeSupplierPart supplierPart;

  @override
  _SupplierPartDisplayState createState() => _SupplierPartDisplayState();
}


class _SupplierPartDisplayState extends RefreshableState<SupplierPartDetailWidget> {

  _SupplierPartDisplayState();

  @override
  String getAppBarTitle() => L10().supplierPart;

  /*
   * Launch a form to edit the current SupplierPart instance
   */
  Future<void> editSupplierPart(BuildContext context) async {
    widget.supplierPart.editForm(
        context,
        L10().supplierPartEdit,
        onSuccess: (data) async {
          refresh(context);
          showSnackIcon(L10().supplierPartUpdated, success: true);
        }
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.supplierPart.canEdit) {
      actions.add(
        customBarcodeAction(
          context, this,
          widget.supplierPart.customBarcode,
          "supplierpart",
          widget.supplierPart.pk
        )
      );
    }

    return actions;
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.supplierPart.canEdit) {
      actions.add(
          IconButton(
              icon: Icon(Icons.edit_square),
              tooltip: L10().edit,
              onPressed: () {
                editSupplierPart(context);
              }
          )
      );
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    final bool result = widget.supplierPart.pk > 0 && await widget.supplierPart.reload();

    if (!result) {
      Navigator.of(context).pop();
    }
  }

  /*
   * Build a set of tiles to display for this SupplierPart
   */
  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    // Internal Part
    tiles.add(
        ListTile(
          title: Text(L10().internalPart),
          subtitle: Text(widget.supplierPart.partName),
          leading: FaIcon(FontAwesomeIcons.shapes, color: COLOR_ACTION),
          trailing: InvenTreeAPI().getThumbnail(widget.supplierPart.partImage),
          onTap: () async {
            showLoadingOverlay(context);
            final part = await InvenTreePart().get(widget.supplierPart.partId);
            hideLoadingOverlay();

            if (part is InvenTreePart) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => PartDetailWidget(part)));
            }
          },
        )
    );

    // Supplier details
    tiles.add(
      ListTile(
        title: Text(L10().supplier),
        subtitle: Text(widget.supplierPart.supplierName),
        leading: FaIcon(FontAwesomeIcons.building, color: COLOR_ACTION),
        trailing: InvenTreeAPI().getThumbnail(widget.supplierPart.supplierImage),
        onTap: () async {
          showLoadingOverlay(context);
          var supplier = await InvenTreeCompany().get(widget.supplierPart.supplierId);
          hideLoadingOverlay();

          if (supplier is InvenTreeCompany) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => CompanyDetailWidget(supplier)
            ));
          }
        }
      )
    );

    // SKU (part number)
    tiles.add(
        ListTile(
          title: Text(L10().supplierPartNumber),
          subtitle: Text(widget.supplierPart.SKU),
          leading: FaIcon(FontAwesomeIcons.barcode),
        )
    );

    // Manufacturer information
    if (widget.supplierPart.manufacturerPartId > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().manufacturer),
          subtitle: Text(widget.supplierPart.manufacturerName),
          leading: FaIcon(FontAwesomeIcons.industry, color: COLOR_ACTION),
          trailing: InvenTreeAPI().getThumbnail(widget.supplierPart.manufacturerImage),
          onTap: () async {
            showLoadingOverlay(context);
            var supplier = await InvenTreeCompany().get(widget.supplierPart.manufacturerId);
            hideLoadingOverlay();

            if (supplier is InvenTreeCompany) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CompanyDetailWidget(supplier)
              ));
            }
          }
        )
      );

      tiles.add(
        ListTile(
          title: Text(L10().manufacturerPartNumber),
          subtitle: Text(widget.supplierPart.MPN),
          leading: FaIcon(FontAwesomeIcons.barcode),
        )
      );
    }

    // Packaging
    if (widget.supplierPart.packaging.isNotEmpty || widget.supplierPart.pack_quantity.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().packaging),
          subtitle: widget.supplierPart.packaging.isNotEmpty ? Text(widget.supplierPart.packaging) : null,
          leading: FaIcon(FontAwesomeIcons.boxesPacking),
          trailing: widget.supplierPart.pack_quantity.isNotEmpty ? Text(widget.supplierPart.pack_quantity) : null,
        )
      );
    }

    if (widget.supplierPart.link.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(widget.supplierPart.link),
          leading: FaIcon(FontAwesomeIcons.link, color: COLOR_ACTION),
          onTap: () async {
            var uri = Uri.tryParse(widget.supplierPart.link);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
        )
      );
    }

    if (widget.supplierPart.note.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(widget.supplierPart.note),
          leading: FaIcon(FontAwesomeIcons.pencil),
        )
      );
    }

    return tiles;
  }

}