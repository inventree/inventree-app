/*
 * Unit tests for the helper functions in helpers.dart
 */

import "package:flutter_test/flutter_test.dart";
import "package:inventree/helpers.dart";

void main() {
  group("Number Helpers:", () {
    test("Simple Number String", () async {
      expect(simpleNumberString(0), equals("0"));
      expect(simpleNumberString(10), equals("10"));
      expect(simpleNumberString(-3), equals("-3"));
      expect(simpleNumberString(1.5), equals("1.5"));
      expect(simpleNumberString(0.25), equals("0.25"));
    });

    test("Valid Number", () async {
      expect(isValidNumber(1.0), isTrue);
      expect(isValidNumber(0), isTrue);
      expect(isValidNumber(-1.5), isTrue);
      expect(isValidNumber(null), isFalse);
      expect(isValidNumber(double.nan), isFalse);
      expect(isValidNumber(double.infinity), isFalse);
      expect(isValidNumber(double.negativeInfinity), isFalse);
    });
  });

  group("Currency Helpers:", () {
    test("Invalid Values", () async {
      expect(renderCurrency(null, "USD"), equals("-"));
      expect(renderCurrency(double.nan, "USD"), equals("-"));
      expect(renderCurrency(double.infinity, "USD"), equals("-"));
      expect(renderCurrency(10, ""), equals("-"));
      expect(renderCurrency(10, "   "), equals("-"));
    });

    test("Render Currency", () async {
      String usd = renderCurrency(12.5, "USD");
      expect(usd, contains("\$"));
      expect(usd, contains("12.50"));

      // Currency code is case insensitive, and whitespace is ignored
      expect(renderCurrency(12.5, " usd "), equals(usd));

      // Unknown currency codes fall back to USD formatting
      expect(renderCurrency(12.5, "XYZ"), equals(usd));

      expect(renderCurrency(12.5, "EUR"), contains("€"));
    });

    test("Price Range", () async {
      String low = renderCurrency(1, "USD");
      String high = renderCurrency(2, "USD");

      expect(formatPriceRange(null, null), equals("-"));
      expect(formatPriceRange(double.nan, double.infinity), equals("-"));

      expect(formatPriceRange(1, 1), equals(low));
      expect(formatPriceRange(1, 2), equals("${low} - ${high}"));

      // Only one valid value
      expect(formatPriceRange(1, null), equals(low));
      expect(formatPriceRange(null, 2), equals(high));
      expect(formatPriceRange(double.nan, 2), equals(high));

      // Currency is passed through
      expect(
        formatPriceRange(1, 2, currency: "EUR"),
        equals("${renderCurrency(1, "EUR")} - ${renderCurrency(2, "EUR")}"),
      );
    });
  });

  group("Debug Helpers:", () {
    test("Debug Messages", () async {
      expect(isTesting(), isTrue);
      expect(hasContext(), isFalse);

      int count = debugMessageCount();

      debug("helpers_test: a unique message");

      expect(debugMessageCount(), equals(count + 1));
      expect(debugContains("helpers_test: a unique message"), isTrue);
      expect(
        debugContains("helpers_test: missing", raiseAssert: false),
        isFalse,
      );
    });
  });
}
