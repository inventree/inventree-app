/*
 * Tests for label print job handling (regression tests for B19).
 *
 * Previously, a print job which did not complete within the polling
 * window (or could not be polled) failed silently.
 *
 * The server responses are simulated, so no server is required.
 */

import "package:flutter_test/flutter_test.dart";
import "package:inventree/api.dart";
import "package:inventree/labels.dart";

// Simulate a sequence of server responses to "data-output/<id>/" requests.
// The final response is repeated once the sequence is exhausted.
class FakeOutputServer {
  FakeOutputServer(this.responses);

  final List<APIResponse> responses;
  final List<String> requests = [];

  Future<APIResponse> fetch(String url) async {
    requests.add(url);
    final int idx = requests.length - 1;
    return responses[idx < responses.length ? idx : responses.length - 1];
  }
}

APIResponse ok(Map<String, dynamic> data) =>
    APIResponse(statusCode: 200, data: data);

Map<String, dynamic> job({
  bool complete = false,
  dynamic errors,
  String? output,
}) => {"pk": 12, "complete": complete, "errors": errors, "output": output};

void main() {
  Future<LabelPrintResult> wait(
    Map<String, dynamic> data,
    FakeOutputServer server, {
    int maxPolls = 5,
  }) => waitForPrintOutput(
    data,
    fetch: server.fetch,
    maxPolls: maxPolls,
    interval: Duration.zero,
  );

  group("Print Job Status:", () {
    test("Complete immediately (synchronous print)", () async {
      final server = FakeOutputServer([]);

      final result = await wait(
        job(complete: true, output: "/media/label.pdf"),
        server,
      );

      expect(result.status, equals(LabelPrintStatus.complete));
      expect(result.output, equals("/media/label.pdf"));
      expect(server.requests, isEmpty);
    });

    test("Completes after polling", () async {
      final server = FakeOutputServer([
        ok(job()),
        ok(job()),
        ok(job(complete: true)),
      ]);

      final result = await wait(job(), server);

      expect(result.status, equals(LabelPrintStatus.complete));
      expect(result.output, isEmpty);
      expect(server.requests, hasLength(3));
      expect(server.requests.first, equals("data-output/12/"));
    });

    test("Server reports an error", () async {
      final server = FakeOutputServer([
        ok(job()),
        ok(job(errors: {"error": "Printer offline"})),
      ]);

      final result = await wait(job(), server);

      expect(result.status, equals(LabelPrintStatus.failed));
      expect(result.error, equals("Printer offline"));
    });

    test("Times out (previously silent)", () async {
      final server = FakeOutputServer([ok(job())]);

      final result = await wait(job(), server, maxPolls: 5);

      expect(result.status, equals(LabelPrintStatus.timedOut));
      expect(server.requests, hasLength(5));
    });

    test("Transient poll failures are retried", () async {
      final server = FakeOutputServer([
        APIResponse(), // No response from server
        APIResponse(statusCode: 503),
        ok(job(complete: true)),
      ]);

      final result = await wait(job(), server);

      expect(result.status, equals(LabelPrintStatus.complete));
      expect(server.requests, hasLength(3));
    });

    test("Persistent poll failures time out", () async {
      final server = FakeOutputServer([APIResponse()]);

      final result = await wait(job(), server, maxPolls: 3);

      expect(result.status, equals(LabelPrintStatus.timedOut));
    });

    test("Job not found stops polling", () async {
      final server = FakeOutputServer([APIResponse(statusCode: 404)]);

      final result = await wait(job(), server);

      expect(result.status, equals(LabelPrintStatus.failed));
      expect(server.requests, hasLength(1));
    });

    test("Missing job ID fails (previously silent)", () async {
      final server = FakeOutputServer([]);

      final result = await wait({"complete": false}, server);

      expect(result.status, equals(LabelPrintStatus.failed));
      expect(server.requests, isEmpty);
    });
  });

  group("Print Job Errors:", () {
    test("No errors", () {
      expect(printOutputError(job()), isNull);
      expect(printOutputError(job(errors: {})), isNull);
      expect(printOutputError(job(errors: [])), isNull);
      expect(printOutputError(job(errors: "")), isNull);
    });

    test("Error formats", () {
      expect(printOutputError(job(errors: {"error": "A"})), equals("A"));
      expect(
        printOutputError(
          job(
            errors: {
              "copies": ["Must be positive"],
            },
          ),
        ),
        equals("Must be positive"),
      );
      expect(printOutputError(job(errors: ["B", "C"])), equals("B"));
      expect(printOutputError(job(errors: "D")), equals("D"));
    });
  });

  group("Worker Status:", () {
    test("Defaults to running when not reported", () {
      final api = InvenTreeAPI();
      final saved = Map<String, dynamic>.from(api.serverInfo);

      api.serverInfo.remove("worker_running");
      expect(api.workerRunning, isTrue);

      api.serverInfo["worker_running"] = false;
      expect(api.workerRunning, isFalse);

      api.serverInfo
        ..clear()
        ..addAll(saved);
    });
  });
}
