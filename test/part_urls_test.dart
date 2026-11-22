/*
 * Unit tests for part API endpoint URLs and version checks
 * (regression tests for B14 and B15).
 *
 * No server is required.
 */

import "package:flutter_test/flutter_test.dart";

import "package:inventree/api.dart";
import "package:inventree/inventree/part.dart";
import "package:inventree/user_profile.dart";

void main() {
  final api = InvenTreeAPI();

  tearDown(() {
    api.serverInfo = {};
    api.profile = null;
  });

  // B14: endpoint URLs are relative to the API root (not the host root)
  group("Part URLs:", () {
    final part = InvenTreePart.fromJson({"pk": 12});

    test("Relative paths", () {
      api.serverInfo = {"apiVersion": 568};

      for (final url in [
        part.serialNumbersUrl,
        part.requirementsUrl,
        part.pricingUrl,
      ]) {
        expect(url.startsWith("/"), isFalse, reason: url);
        expect(url.contains("api/"), isFalse, reason: url);
      }

      expect(part.serialNumbersUrl, equals("part/12/serial-numbers/"));
      expect(part.requirementsUrl, equals("part/12/requirements/"));
    });

    test("Pricing URL depends on server version", () {
      api.serverInfo = {"apiVersion": 561};
      expect(part.pricingUrl, equals("part/12/pricing/"));

      api.serverInfo = {"apiVersion": 562};
      expect(part.pricingUrl, equals("pricing/part/12/"));
    });

    test("Resolved against the server API root", () {
      api.profile = UserProfile(name: "Test", server: "https://example.com");

      expect(
        api.makeApiUrl(part.serialNumbersUrl),
        equals("https://example.com/api/part/12/serial-numbers/"),
      );

      expect(
        api.makeApiUrl("locate/"),
        equals("https://example.com/api/locate/"),
      );
    });
  });

  // B15: the generic parameter API was added in v430 (not v429)
  test("Modern parameters version", () {
    api.serverInfo = {"apiVersion": 429};
    expect(api.supportsModernParameters, isFalse);

    api.serverInfo = {"apiVersion": 430};
    expect(api.supportsModernParameters, isTrue);
  });
}
