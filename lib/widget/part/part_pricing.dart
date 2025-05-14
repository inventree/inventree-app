import "package:flutter/material.dart";

import "package:inventree/inventree/part.dart";
import "package:inventree/l10.dart";

import "package:inventree/widget/refreshable_state.dart";

class PartPricingWidget extends StatefulWidget {

  const PartPricingWidget({Key? key, required this.part}) : super(key: key);
  final InvenTreePart part;

  @override
  _PartPricingWidgetState createState() => _PartPricingWidgetState();
}

class _PartPricingWidgetState extends RefreshableState<PartPricingWidget> {
  String? currency;
  String? bomCostMin;
  String? bomCostMax;
  String? purchaseCostMin;
  String? purchaseCostMax;
  String? internalCostMin;
  String? internalCostMax;
  String? supplierPriceMin;
  String? supplierPriceMax;
  String? variantCostMin;
  String? variantCostMax;
  String? salePriceMin;
  String? salePriceMax;
  String? saleHistoryMin;
  String? saleHistoryMax;
  String? overallMin;
  String? overallMax;
  String? overrideMin;
  String? overrideMinCurrency;
  String? overrideMax;
  String? overrideMaxCurrency;
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

    // Helper function to format prices
    String formatPrice(String? value, [String? currency]) {
      if (value == "null") return "N/A";
      return "${currency ?? ''} $value";
    }

    // Helper function to format price ranges
    String? formatPriceRange(String? min, String? max) {
      if ((min == "null") && (max == "null")) {
        return null;
      }

      if (min == "null") {
        return max;
      }

      if (max == "null") {
        return min;
      }

      return "$min - $max";
    }

    final pricingFields = {
      "${L10().currency}": currency,
      "${L10().salePrice}": formatPriceRange(salePriceMin, salePriceMax),
      "${L10().saleHistory}": formatPriceRange(saleHistoryMin, saleHistoryMax),
      "${L10().supplierPricing}": formatPriceRange(supplierPriceMin, supplierPriceMax),
      "${L10().bomCost}": formatPriceRange(bomCostMin, bomCostMax),
      "${L10().purchasePrice}": formatPriceRange(purchaseCostMin, purchaseCostMax),
      "${L10().internalCost}": formatPriceRange(internalCostMin, internalCostMax),
      "${L10().variantCost}": formatPriceRange(variantCostMin, variantCostMax),
      "${L10().overallPricing}": formatPriceRange(overallMin, overallMax),
      "${L10().pricingOverrides}": formatPriceRange(
          formatPrice(overrideMin, overrideMinCurrency),
          formatPrice(overrideMax, overrideMaxCurrency)
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

    return tiles;

  }

  Future<void> _loadPricingData() async {
    try {
      await widget.part.getPricing();
      setState(() {
        currency = widget.part.currency;
        salePriceMin = widget.part.salePriceMin?.toString() ?? "N/A";
        salePriceMax = widget.part.salePriceMax?.toString() ?? "N/A";
        supplierPriceMin = widget.part.supplierPriceMin?.toString() ?? "N/A";
        supplierPriceMax = widget.part.supplierPriceMax?.toString() ?? "N/A";
        bomCostMin = widget.part.bomCostMin?.toString() ?? "N/A";
        bomCostMax = widget.part.bomCostMax?.toString() ?? "N/A";
        purchaseCostMin = widget.part.purchaseCostMin?.toString() ?? "N/A";
        purchaseCostMax = widget.part.purchaseCostMax?.toString() ?? "N/A";
        internalCostMin = widget.part.internalCostMin?.toString() ?? "N/A";
        internalCostMax = widget.part.internalCostMax?.toString() ?? "N/A";
        variantCostMin = widget.part.variantCostMin?.toString() ?? "N/A";
        variantCostMax = widget.part.variantCostMax?.toString() ?? "N/A";
        saleHistoryMin = widget.part.saleHistoryMin?.toString() ?? "N/A";
        saleHistoryMax = widget.part.saleHistoryMax?.toString() ?? "N/A";
        overallMin = widget.part.overallMin?.toString() ?? "N/A";
        overallMax = widget.part.overallMax?.toString() ?? "N/A";
        overrideMin = widget.part.overrideMin?.toString() ?? "N/A";
        overrideMinCurrency = widget.part.overrideMinCurrency;
        overrideMax = widget.part.overrideMax?.toString() ?? "N/A";
        overrideMaxCurrency = widget.part.overrideMaxCurrency ?? "N/A";
        priceBreaks = widget.part.priceBreaks;
        isLoading = false;
      });
    } catch (e) {
      print("Failed to load pricing data: $e");
      setState(() => isLoading = false);
    }
  }
}
