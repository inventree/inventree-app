/*
 * Unit tests for the error message helpers in dialogs.dart
 *
 * These tests do not require a connection to the server
 */

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/dialogs.dart";

// Display the error content for the given description / response
Future<void> pumpErrorContent(
  WidgetTester tester, {
  String description = "",
  APIResponse? response,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: buildErrorContent(description, response))),
  );
}

// Return the text of every Text widget which is displayed
List<String> displayedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? "")
    .toList();

void main() {
  group("Status Codes:", () {
    test("Known Codes", () async {
      final Map<int, String> codes = {
        400: L10().response400,
        401: L10().response401,
        403: L10().response403,
        404: L10().response404,
        405: L10().response405,
        429: L10().response429,
        500: L10().response500,
        501: L10().response501,
        502: L10().response502,
        503: L10().response503,
        504: L10().response504,
        505: L10().response505,
      };

      for (final entry in codes.entries) {
        expect(
          statusCodeToString(entry.key),
          equals(entry.value),
          reason: "status ${entry.key}",
        );
      }

      // Each code has a distinct message
      expect(codes.values.toSet().length, equals(codes.length));
    });

    test("Unknown Codes", () async {
      for (final status in [-1, 0, 200, 418, 599]) {
        expect(
          statusCodeToString(status),
          equals("${L10().responseInvalid} : ${status}"),
        );
      }
    });
  });

  group("Error Details:", () {
    test("Preferred Keys", () async {
      expect(extractErrorDetails({"detail": "Not found"}), equals("Not found"));
      expect(extractErrorDetails({"error": "Bad barcode"}), "Bad barcode");
      expect(
        extractErrorDetails({
          "errors": ["first", "second"],
        }),
        equals("first\nsecond"),
      );

      // 'detail' takes priority over 'error'
      expect(extractErrorDetails({"error": "B", "detail": "A"}), equals("A"));

      // Null values are skipped
      expect(extractErrorDetails({"detail": null, "error": "B"}), equals("B"));

      // Non-string values are converted
      expect(extractErrorDetails({"detail": 42}), equals("42"));
    });

    test("Fallback To Key Value Pairs", () async {
      expect(
        extractErrorDetails({
          "quantity": ["Must be positive"],
          "part": "Required",
        }),
        equals("quantity: [Must be positive]\npart: Required"),
      );

      expect(extractErrorDetails({}), equals(""));

      // Null values for preferred keys fall back to the raw data
      expect(extractErrorDetails({"detail": null}), equals("detail: null"));
    });

    test("Other Types", () async {
      expect(extractErrorDetails(["a", 1]), equals("a\n1"));
      expect(extractErrorDetails([]), equals(""));
      expect(extractErrorDetails("plain text"), equals("plain text"));
      expect(extractErrorDetails(null), equals(""));
      expect(extractErrorDetails(123), equals(""));
    });
  });

  group("Field Names:", () {
    test("Humanize", () async {
      expect(humanizeFieldName("target_date"), equals("Target Date"));
      expect(humanizeFieldName("quantity"), equals("Quantity"));
      expect(humanizeFieldName("__all__"), equals("All"));
      expect(humanizeFieldName("part__name"), equals("Part Name"));
      expect(humanizeFieldName(""), equals(""));
    });
  });

  group("Error Content:", () {
    testWidgets("Description", (tester) async {
      // A description takes priority over the response
      await pumpErrorContent(
        tester,
        description: "Something went wrong",
        response: APIResponse(statusCode: 400, data: {"detail": "Ignored"}),
      );

      expect(displayedText(tester), equals(["Something went wrong"]));
    });

    testWidgets("Empty", (tester) async {
      await pumpErrorContent(tester);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets("Detail", (tester) async {
      await pumpErrorContent(
        tester,
        response: APIResponse(
          statusCode: 403,
          data: {"detail": "Permission denied", "other": "Ignored"},
        ),
      );

      expect(displayedText(tester), equals(["Permission denied"]));
    });

    testWidgets("Non Field Errors", (tester) async {
      await pumpErrorContent(
        tester,
        response: APIResponse(
          statusCode: 409,
          data: {
            "non_field_errors": ["Order is locked", "Order is closed"],
            "__all__": "Invalid order",
            "errors": ["Something else"],
            "quantity": ["Not displayed (not a 400 response)"],
          },
        ),
      );

      expect(
        displayedText(tester),
        equals([
          "Order is locked",
          "Order is closed",
          "Invalid order",
          "Something else",
        ]),
      );
    });

    testWidgets("Field Errors", (tester) async {
      await pumpErrorContent(
        tester,
        response: APIResponse(
          statusCode: 400,
          data: {
            "non_field_errors": ["Form is invalid"],
            "target_date": ["Date is in the past", "Date is invalid"],
            "quantity": "Must be positive",
          },
        ),
      );

      expect(
        displayedText(tester),
        equals([
          "Form is invalid",
          "Target Date",
          "Date is in the past",
          "Date is invalid",
          "Quantity",
          "Must be positive",
        ]),
      );
    });

    testWidgets("Unrecognized Data", (tester) async {
      // Not a map - fall back to the raw data
      await pumpErrorContent(
        tester,
        response: APIResponse(statusCode: 500, data: "Internal Server Error"),
      );

      expect(
        displayedText(tester),
        equals([
          L10().response500,
          L10().responseData,
          "Internal Server Error",
        ]),
      );
    });

    testWidgets("Empty Field Errors", (tester) async {
      // A 400 response with no data
      await pumpErrorContent(
        tester,
        response: APIResponse(statusCode: 400, data: <String, dynamic>{}),
      );

      expect(
        displayedText(tester),
        equals([L10().response400, L10().responseData, "{}"]),
      );
    });
  });
}
