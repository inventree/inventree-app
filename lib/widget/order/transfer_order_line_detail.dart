import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/helpers.dart";
import "package:inventree/l10.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/inventree/transfer_order.dart";

import "package:inventree/widget/link_icon.dart";
import "package:inventree/widget/order/transfer_order_allocation_list.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Widget for displaying detail view of a single TransferOrderLineItem
 */
class TransferOrderLineDetailWidget extends StatefulWidget {
  const TransferOrderLineDetailWidget(this.item, {Key? key}) : super(key: key);

  final InvenTreeTransferOrderLineItem item;

  @override
  _TransferOrderLineDetailState createState() =>
      _TransferOrderLineDetailState();
}

class _TransferOrderLineDetailState
    extends RefreshableState<TransferOrderLineDetailWidget> {
  _TransferOrderLineDetailState();

  @override
  String getAppBarTitle() => L10().lineItem;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    if (widget.item.canEdit) {
      actions.add(
        IconButton(
          icon: Icon(TablerIcons.edit),
          onPressed: () {
            _editLineItem(context);
          },
        ),
      );
    }

    return actions;
  }

  @override
  Future<void> request(BuildContext context) async {
    await widget.item.reload();
  }

  // Callback to edit this line item
  Future<void> _editLineItem(BuildContext context) async {
    var fields = widget.item.formFields();

    widget.item.editForm(
      context,
      L10().editLineItem,
      fields: fields,
      onSuccess: (data) async {
        refresh(context);
        showSnackIcon(L10().lineItemUpdated, success: true);
      },
    );
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [];

    if (showPk) {
      tiles.add(pkTile(widget.item.pk));
    }

    // Reference to the part
    tiles.add(
      ListTile(
        title: Text(L10().part),
        subtitle: Text(widget.item.partName),
        leading: InvenTreeAPI().getThumbnail(widget.item.partImage),
        trailing: LinkIcon(),
        onTap: () async {
          showLoadingOverlay();
          var part = await InvenTreePart().get(widget.item.partId);
          hideLoadingOverlay();

          if (part is InvenTreePart) {
            part.goToDetailPage(context);
          }
        },
      ),
    );

    // Transferred quantity
    tiles.add(
      ListTile(
        title: Text(L10().transfer),
        subtitle: ProgressBar(widget.item.progressRatio),
        trailing: LargeText(
          widget.item.progressString,
          color: widget.item.isComplete ? COLOR_SUCCESS : COLOR_WARNING,
        ),
        leading: Icon(TablerIcons.progress),
      ),
    );

    // Allocated stock items
    tiles.add(
      ListTile(
        title: Text(L10().allocatedStock),
        leading: Icon(TablerIcons.clipboard_check, color: COLOR_ACTION),
        trailing: LinkIcon(text: simpleNumberString(widget.item.allocated)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransferOrderAllocationWidget(widget.item),
          ),
        ),
      ),
    );

    // Reference
    if (widget.item.reference.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().reference),
          subtitle: Text(widget.item.reference),
          leading: Icon(TablerIcons.hash),
        ),
      );
    }

    // Target date
    if (widget.item.targetDate.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().targetDate),
          subtitle: Text(widget.item.targetDate),
          leading: Icon(TablerIcons.calendar),
        ),
      );
    }

    // Notes
    if (widget.item.notes.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().notes),
          subtitle: Text(widget.item.notes),
          leading: Icon(TablerIcons.note),
        ),
      );
    }

    // External link
    if (widget.item.hasLink) {
      tiles.add(
        ListTile(
          title: Text(L10().link),
          subtitle: Text(widget.item.link),
          leading: Icon(TablerIcons.link, color: COLOR_ACTION),
          onTap: () async {
            await openLink(widget.item.link);
          },
        ),
      );
    }

    return tiles;
  }
}
