import "package:flutter/material.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/l10.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/helpers.dart";

class PartPricingWidget extends StatefulWidget {
  const PartPricingWidget(
      {Key? key, required this.part, required this.partPricing})
      : super(key: key);
  final InvenTreePart part;
  final InvenTreePartPricing? partPricing;

  @override
  _PartPricingWidgetState createState() => _PartPricingWidgetState();
}

class _PartPricingWidgetState extends RefreshableState<PartPricingWidget> {
  @override
  String getAppBarTitle() {
    return L10().partPricing;
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    List<Widget> tiles = [
      Card(
          child: ListTile(
              title: Text(widget.part.fullname),
              subtitle: Text(widget.part.description),
              leading: api.getThumbnail(widget.part.thumbnail))),
    ];

    if (widget.partPricing == null) {
      tiles.add(ListTile(
        title: Text(L10().noPricingAvailable),
        subtitle: Text(L10().noPricingDataFound),
      ));

      return tiles;
    }

    final pricing = widget.partPricing!;

    tiles.add(ListTile(
      title: Text(L10().currency),
      trailing: Text(pricing.currency),
    ));

    tiles.add(ListTile(
      title: Text(L10().priceRange),
      trailing: Text(formatPriceRange(pricing.overallMin, pricing.overallMax,
          currency: pricing.currency)),
    ));

    if (pricing.overallMin != null) {
      tiles.add(ListTile(
          title: Text(L10().priceOverrideMin),
          trailing: Text(renderCurrency(
              pricing.overallMin, pricing.overrideMinCurrency))));
    }

    if (pricing.overrideMax != null) {
      tiles.add(ListTile(
          title: Text(L10().priceOverrideMax),
          trailing: Text(renderCurrency(
              pricing.overallMax, pricing.overrideMaxCurrency))));
    }

    tiles.add(ListTile(
      title: Text(L10().internalCost),
      trailing: Text(formatPriceRange(
          pricing.internalCostMin, pricing.internalCostMax,
          currency: pricing.currency)),
    ));

    if (widget.part.isTemplate) {
      tiles.add(ListTile(
        title: Text(L10().variantCost),
        trailing: Text(formatPriceRange(
            pricing.variantCostMin, pricing.variantCostMax,
            currency: pricing.currency)),
      ));
    }

    if (widget.part.isAssembly) {
      tiles.add(ListTile(
          title: Text(L10().bomCost),
          trailing: Text(formatPriceRange(
              pricing.bomCostMin, pricing.bomCostMax,
              currency: pricing.currency))));
    }

    if (widget.part.isPurchaseable) {
      tiles.add(ListTile(
        title: Text(L10().purchasePrice),
        trailing: Text(formatPriceRange(
            pricing.purchaseCostMin, pricing.purchaseCostMax,
            currency: pricing.currency)),
      ));

      tiles.add(ListTile(
        title: Text(L10().supplierPricing),
        trailing: Text(formatPriceRange(
            pricing.supplierPriceMin, pricing.supplierPriceMax,
            currency: pricing.currency)),
      ));
    }

    if (widget.part.isSalable) {
      tiles.add(Divider());

      tiles.add(ListTile(
        title: Text(L10().salePrice),
        trailing: Text(formatPriceRange(
            pricing.salePriceMin, pricing.salePriceMax,
            currency: pricing.currency)),
      ));

      tiles.add(ListTile(
        title: Text(L10().saleHistory),
        trailing: Text(formatPriceRange(
            pricing.saleHistoryMin, pricing.saleHistoryMax,
            currency: pricing.currency)),
      ));
    }

    return tiles;
  }
}
