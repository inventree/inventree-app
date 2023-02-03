import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/company.dart";

import "package:inventree/widget/company_detail.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import 'package:inventree/widget/snacks.dart';
import 'package:url_launcher/url_launcher.dart';


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
  String getAppBarTitle(BuildContext context) => L10().supplierPart;

  @override
  List<Widget> getAppBarActions(BuildContext context) {
    List<Widget> actions = [];

    actions.add(
      IconButton(
        icon: FaIcon(FontAwesomeIcons.edit),
        tooltip: L10().edit,
        onPressed: () {
          editSupplierPart(context);
        },
      )
    );

    return actions;
  }

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
  Future<void> request(BuildContext context) async {
    final bool result = widget.supplierPart.pk > 0 && await widget.supplierPart.reload();

    if (!result) {
      Navigator.of(context).pop();
    }
  }

  /*
   * Build a set of tiles to display for this SupplierPart
   */
  List<Widget> detailTiles(BuildContext context) {
    List<Widget> tiles = [];

    if (loading) {
      tiles.add(progressIndicator());
      return tiles;
    }

    // Internal Part
    tiles.add(
        ListTile(
          title: Text(widget.supplierPart.partName),
          subtitle: Text(widget.supplierPart.partDescription),
          leading: InvenTreeAPI().getImage(
            widget.supplierPart.partImage,
            width: 40,
            height: 40,
          ),
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

    // Supplier part details
    tiles.add(
      ListTile(
        title: Text(widget.supplierPart.SKU),
        subtitle: Text(widget.supplierPart.supplierName),
        leading: FaIcon(FontAwesomeIcons.building),
        trailing: InvenTreeAPI().getImage(
          widget.supplierPart.supplierImage,
          width: 40,
          height: 40,
        ),
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

    // Manufacturer information
    if (widget.supplierPart.manufacturerPartId > 0) {
      tiles.add(
        ListTile(
          subtitle: Text(widget.supplierPart.manufacturerName),
          title: Text(widget.supplierPart.MPN),
          leading: FaIcon(FontAwesomeIcons.industry),
          trailing: InvenTreeAPI().getImage(
            widget.supplierPart.manufacturerImage,
            width: 40,
            height: 40,
          )
        )
      );
    }

    if (widget.supplierPart.link.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(widget.supplierPart.link),
          leading: FaIcon(FontAwesomeIcons.link),
          onTap: () async {
            if (await canLaunch(widget.supplierPart.link)) {
              await launch(widget.supplierPart.link);
            }
          },
        )
      );
    }

    if (widget.supplierPart.note.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(widget.supplierPart.note),
          leading: FaIcon(FontAwesomeIcons.pencilAlt),
        )
      );
    }

    return tiles;
  }

  /*
   * Build the widget
   */
  @override
  Widget getBody(BuildContext context) {
    return ListView(
      children: ListTile.divideTiles(
        context: context,
        tiles: detailTiles(context),
      ).toList()
    );
  }

}