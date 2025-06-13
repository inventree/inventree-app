import "package:flutter/material.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/l10.dart";

import "package:inventree/widget/refreshable_state.dart";
import "package:inventree/helpers.dart";

class PartPricingWidget extends StatefulWidget {

  const PartPricingWidget({Key? key, required this.part}) : super(key: key);
  final InvenTreePart part;

  @override
  _PartPricingWidgetState createState() => _PartPricingWidgetState();
}

class _PartPricingWidgetState extends RefreshableState<PartPricingWidget> {
  List<String> priceBreaks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPricingData();
  }

  @override
  String getAppBarTitle() {
    return "Part Pricing";
  }

  @override
  List<Widget> getTiles(BuildContext context) {
    if (isLoading) {
      return [
        Container(
          height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
          alignment: Alignment.center,
          child: CircularProgressIndicator(),
        ),
      ];
    }

    final pricingFields = {
      "${L10().currency}": widget.part.currency,
      "${L10().salePrice}": formatPriceRange(
          formatPrice(widget.part.salePriceMin?.toString(), widget.part.currency),
          formatPrice(widget.part.salePriceMax?.toString(), widget.part.currency)
      ),
      "${L10().saleHistory}": formatPriceRange(
          formatPrice(widget.part.saleHistoryMin?.toString(), widget.part.currency),
          formatPrice(widget.part.saleHistoryMax?.toString(), widget.part.currency)
      ),
      "${L10().supplierPricing}": formatPriceRange(
          formatPrice(widget.part.supplierPriceMin?.toString(), widget.part.currency),
          formatPrice(widget.part.supplierPriceMax?.toString(), widget.part.currency)
      ),
      "${L10().bomCost}": formatPriceRange(
          formatPrice(widget.part.bomCostMin?.toString(), widget.part.currency),
          formatPrice(widget.part.bomCostMax?.toString(), widget.part.currency)
      ),
      "${L10().purchasePrice}": formatPriceRange(
          formatPrice(widget.part.purchaseCostMin?.toString(), widget.part.currency),
          formatPrice(widget.part.purchaseCostMax?.toString(), widget.part.currency)
      ),
      "${L10().internalCost}": formatPriceRange(
          formatPrice(widget.part.internalCostMin?.toString(), widget.part.currency),
          formatPrice(widget.part.internalCostMax?.toString(), widget.part.currency)
      ),
      "${L10().variantCost}": formatPriceRange(
          formatPrice(widget.part.variantCostMin?.toString(), widget.part.currency),
          formatPrice(widget.part.variantCostMax?.toString(), widget.part.currency)
      ),
      "${L10().overallPricing}": formatPriceRange(
          formatPrice(widget.part.overallMin?.toString(), widget.part.currency),
          formatPrice(widget.part.overallMax?.toString(), widget.part.currency)
      ),
      "${L10().pricingOverrides}": formatPriceRange(
          formatPrice(widget.part.overrideMin?.toString(), widget.part.overrideMinCurrency),
          formatPrice(widget.part.overrideMax?.toString(), widget.part.overrideMaxCurrency)
      ),
    };

    List<Widget> tiles = pricingFields.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => ListTile(
      title: Text(entry.key),
      subtitle: Text(entry.value!),
    ))
        .toList();

    if (priceBreaks.isNotEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().priceBreaks),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: priceBreaks.map((breakDetail) => Text(breakDetail)).toList(),
          ),
        ),
      );
    }

    if (tiles.isEmpty && priceBreaks.isEmpty) {
      tiles.add(
        ListTile(
          title: Text(L10().noPricingAvailable),
          subtitle: Text(L10().noPricingDataFound),
        ),
      );
    }


    return tiles;

  }

  Future<void> _loadPricingData() async {
    try {
      await widget.part.getPricing();
      if (mounted) {
        setState(() {
          priceBreaks = widget.part.priceBreaks;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Failed to load pricing data: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}
