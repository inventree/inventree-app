/*
 * Unit tests for APIFormField (no server or widgets required)
 */

import "package:flutter_test/flutter_test.dart";
import "package:inventree/api.dart";
import "package:inventree/api_form.dart";

void main() {
  group("Extract Fields:", () {
    test("Invalid Response", () async {
      expect(extractFields(APIResponse()), isEmpty);
      expect(extractFields(APIResponse(statusCode: 500)), isEmpty);
    });

    test("No Actions", () async {
      expect(
        extractFields(APIResponse(statusCode: 200, data: {"name": "x"})),
        isEmpty,
      );

      expect(
        extractFields(
          APIResponse(statusCode: 200, data: {"actions": <String, dynamic>{}}),
        ),
        isEmpty,
      );
    });

    test("Action Priority", () async {
      Map<String, dynamic> fields(Map<String, dynamic> actions) =>
          extractFields(
            APIResponse(statusCode: 200, data: {"actions": actions}),
          );

      expect(
        fields({
          "POST": {"a": {}},
          "PUT": {"b": {}},
        }).keys,
        equals(["a"]),
      );

      expect(
        fields({
          "PUT": {"b": {}},
          "PATCH": {"c": {}},
        }).keys,
        equals(["b"]),
      );

      expect(
        fields({
          "PATCH": {"c": {}},
        }).keys,
        equals(["c"]),
      );
    });
  });

  group("Form Field:", () {
    test("Defaults", () async {
      final field = APIFormField("name", {});

      expect(field.pk_field, equals("pk"));
      expect(field.api_url, equals(""));
      expect(field.model, equals(""));
      expect(field.hidden, isFalse);
      expect(field.nested, isFalse);
      expect(field.parent, equals(""));
      expect(field.isSimple, isTrue);
      expect(field.readOnly, isFalse);
      expect(field.multiline, isFalse);
      expect(field.required, isFalse);
      expect(field.type, equals(""));
      expect(field.label, equals(""));
      expect(field.helpText, equals(""));
      expect(field.placeholderText, equals(""));
      expect(field.choices, isEmpty);
      expect(field.value, isNull);
      expect(field.defaultValue, isNull);
      expect(field.filters, isEmpty);
      expect(field.hasErrors(), isFalse);
      expect(field.renderValueToString(), equals(""));
    });

    test("Parameters", () async {
      final field = APIFormField("part", {"label": "Local Label"});

      field.definition = {
        "label": "Server Label",
        "help_text": "Select a part",
        "type": "related field",
        "required": true,
        "read_only": false,
        "model": "part",
        "api_url": "/api/part/",
        "placeholder": "Part",
        "choices": [
          {"value": 1, "display_name": "One"},
        ],
      };

      // Local data takes priority over the server definition
      expect(field.label, equals("Local Label"));

      expect(field.helpText, equals("Select a part"));
      expect(field.type, equals("related field"));
      expect(field.required, isTrue);
      expect(field.readOnly, isFalse);
      expect(field.model, equals("part"));
      expect(field.api_url, equals("/api/part/"));
      expect(field.placeholderText, equals("Part"));
      expect(field.choices.length, equals(1));
      expect(field.getParameter("missing"), isNull);
    });

    test("Value", () async {
      final field = APIFormField("quantity", {});

      field.definition = {"default": 1};
      expect(field.value, equals(1));

      field.data["instance_value"] = 5;
      expect(field.value, equals(5));

      // Value is not rendered from the default or instance value
      expect(field.renderValueToString(), equals(""));

      field.setFieldValue(10);
      expect(field.value, equals(10));
      expect(field.renderValueToString(), equals("10"));
    });

    test("Lookup Path", () async {
      expect(APIFormField("name", {}).lookupPath, equals("name"));

      expect(
        APIFormField("quantity", {"parent": "items"}).lookupPath,
        equals("items.child"),
      );

      expect(
        APIFormField("quantity", {"nested": true}).lookupPath,
        equals("children.quantity"),
      );

      final field = APIFormField("quantity", {
        "parent": "items",
        "nested": true,
      });

      expect(field.isSimple, isFalse);
      expect(field.lookupPath, equals("items.child.children.quantity"));
    });

    test("Filters", () async {
      final field = APIFormField("location", {
        "filters": {"structural": false, "parent": 3},
      });

      field.definition = {
        "filters": {"active": true, "parent": 1},
        "instance_filters": {"category": 2},
      };

      // Filters are merged, with local filters taking priority
      expect(
        field.filters,
        equals({
          "active": "true",
          "parent": "3",
          "category": "2",
          "structural": "false",
        }),
      );

      // Malformed filters are ignored
      final invalid = APIFormField("location", {"filters": "invalid"});
      invalid.definition = {"filters": 1, "instance_filters": []};

      expect(invalid.filters, isEmpty);
    });
  });

  group("Form Field Errors:", () {
    test("Simple Field", () async {
      final field = APIFormField("name", {});

      field.extractErrorMessages(
        APIResponse(
          statusCode: 400,
          data: {
            "name": ["This field is required", "Too short"],
          },
        ),
      );

      expect(field.hasErrors(), isTrue);
      expect(
        field.errorMessages(),
        equals(["This field is required", "Too short"]),
      );

      // Single string error message
      field.extractErrorMessages(
        APIResponse(statusCode: 400, data: {"name": "Invalid name"}),
      );

      expect(field.errorMessages(), equals(["Invalid name"]));

      // No error for this field
      field.extractErrorMessages(
        APIResponse(statusCode: 400, data: {"other": "error"}),
      );

      expect(field.hasErrors(), isFalse);
    });

    test("Nested Field", () async {
      final field = APIFormField("quantity", {
        "parent": "items",
        "nested": true,
      });

      // Errors returned as a list (one entry per nested item)
      field.extractErrorMessages(
        APIResponse(
          statusCode: 400,
          data: {
            "items": [
              {
                "quantity": ["Must be positive"],
              },
            ],
          },
        ),
      );

      expect(field.errorMessages(), equals(["Must be positive"]));

      // Errors returned as a map
      field.extractErrorMessages(
        APIResponse(
          statusCode: 400,
          data: {
            "items": {"quantity": "Invalid quantity"},
          },
        ),
      );

      expect(field.errorMessages(), equals(["Invalid quantity"]));

      // Parent element is missing
      field.extractErrorMessages(APIResponse(statusCode: 400, data: {}));

      expect(field.hasErrors(), isFalse);
    });

    test("Nested Field Without Parent", () async {
      // A nested field with no parent cannot be matched to errors
      final field = APIFormField("quantity", {"nested": true});

      field.extractErrorMessages(
        APIResponse(statusCode: 400, data: {"quantity": "error"}),
      );

      expect(field.hasErrors(), isFalse);
    });
  });
}
