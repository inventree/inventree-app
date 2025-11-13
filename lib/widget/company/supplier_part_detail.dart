import "package:flutter/material.dart";
import "package:flutter_speed_dial/flutter_speed_dial.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/helpers.dart";
import "package:inventree/widget/link_icon.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/l10.dart";

import "package:inventree/barcode/barcode.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/company.dart";

import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/company/manufacturer_part_detail.dart";
import "package:inventree/widget/stock/stock_list.dart";

/*
 * Detail widget for viewing a single SupplierPart instance
 */
class SupplierPartDetailWidget extends StatefulWidget {
  const SupplierPartDetailWidget(this.supplierPart, {Key? key})
    : super(key: key);

  final InvenTreeSupplierPart supplierPart;

  @override
  _SupplierPartDisplayState createState() => _SupplierPartDisplayState();
}

class _SupplierPartDisplayState
    extends RefreshableState<SupplierPartDetailWidget> {
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
      },
    );
  }

  @override
  List<SpeedDialChild> barcodeButtons(BuildContext context) {
    List<SpeedDialChild> actions = [];

    if (widget.supplierPart.canEdit) {
      actions.add(
        customBarcodeAction(
          context,
          this,
          widget.supplierPart.customBarcode,
          "supplierpart",
          widget.supplierPart.pk,
        ),
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
          icon: Icon(TablerIcons.edit),
          tooltip: L10().edit,
          onPressed: () {
            editSupplierPart(context);
          },
        ),
      );
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    final bool result =
        widget.supplierPart.pk > 0 && await widget.supplierPart.reload();

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
        leading: Icon(TablerIcons.box, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () async {
          showLoadingOverlay();
          final part = await InvenTreePart().get(widget.supplierPart.partId);
          hideLoadingOverlay();

          if (part is InvenTreePart) {
            part.goToDetailPage(context);
          }
        },
      ),
    );

    if (!widget.supplierPart.active) {
      tiles.add(
        ListTile(
          title: Text(L10().inactive, style: TextStyle(color: COLOR_DANGER)),
          subtitle: Text(
            L10().inactiveDetail,
            style: TextStyle(color: COLOR_DANGER),
          ),
          leading: Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER),
        ),
      );
    }

    // Stock levels associated with this SupplierPart
    tiles.add(
      ListTile(
        title: Text(L10().availableStock),
        leading: Icon(TablerIcons.packages),
        trailing: LinkIcon(text: simpleNumberString(widget.supplierPart.inStock)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockItemList({
                "in_stock": "true",
                "supplier_part": widget.supplierPart.pkString
              })
            )
          );
        },
      )
    );

    // Supplier details
    tiles.add(
      ListTile(
        title: Text(L10().supplier),
        subtitle: Text(widget.supplierPart.supplierName),
        leading: Icon(TablerIcons.building, color: COLOR_ACTION),
        trailing: LinkIcon(),
        onTap: () async {
          showLoadingOverlay();
          var supplier = await InvenTreeCompany().get(
            widget.supplierPart.supplierId,
          );
          hideLoadingOverlay();

          if (supplier is InvenTreeCompany) {
            supplier.goToDetailPage(context);
          }
        },
      ),
    );

    // SKU (part number)
    tiles.add(
      ListTile(
        title: Text(L10().supplierPartNumber),
        subtitle: Text(widget.supplierPart.SKU),
        leading: Icon(TablerIcons.hash),
      ),
    );

    // Manufacturer information
    if (widget.supplierPart.manufacturerPartId > 0) {
      tiles.add(
        ListTile(
          title: Text(L10().manufacturer),
          subtitle: Text(widget.supplierPart.manufacturerName),
          leading: Icon(TablerIcons.building_factory_2, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () async {
            showLoadingOverlay();
            var supplier = await InvenTreeCompany().get(
              widget.supplierPart.manufacturerId,
            );
            hideLoadingOverlay();

            if (supplier is InvenTreeCompany) {
              supplier.goToDetailPage(context);
            }
          },
        ),
      );

      tiles.add(
        ListTile(
          title: Text(L10().manufacturerPart),
          subtitle: Text(widget.supplierPart.MPN),
          leading: Icon(TablerIcons.hash, color: COLOR_ACTION),
          trailing: LinkIcon(),
          onTap: () async {
            showLoadingOverlay();
            var manufacturerPart = await InvenTreeManufacturerPart().get(
              widget.supplierPart.manufacturerPartId,
            );
            hideLoadingOverlay();

            if (manufacturerPart is InvenTreeManufacturerPart) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ManufacturerPartDetailWidget(manufacturerPart),
                ),
              );
            }
          },
        ),
      );
    }

    // Packaging
    if (widget.supplierPart.packaging.isNotEmpty ||
        widget.supplierPart.pack_quantity.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().packaging),
          subtitle: widget.supplierPart.packaging.isNotEmpty
              ? Text(widget.supplierPart.packaging)
              : null,
          leading: Icon(TablerIcons.package),
          trailing: widget.supplierPart.pack_quantity.isNotEmpty
              ? LargeText(widget.supplierPart.pack_quantity)
              : null,
        ),
      );
    }

    if (widget.supplierPart.hasLink) {
      tiles.add(
        ListTile(
          title: Text(L10().link),
          subtitle: Text(widget.supplierPart.link),
          leading: Icon(TablerIcons.link, color: COLOR_ACTION),
          trailing: LinkIcon(external: true),
          onTap: () async {
            widget.supplierPart.openLink();
          },
        ),
      );
    }

    if (widget.supplierPart.note.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().notes),
          subtitle: Text(widget.supplierPart.note),
          leading: Icon(TablerIcons.pencil),
        ),
      );
    }

    return tiles;
  }
}
