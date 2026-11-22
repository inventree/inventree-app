import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:inventree/preferences.dart";
import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/snacks.dart";

const String PRINT_LABEL_URL = "label/print/";

/*
 * Custom form handler for label printing.
 * Required to manage dynamic form fields.
 */
class LabelFormWidgetState extends APIFormWidgetState {
  LabelFormWidgetState() : super();

  List<APIFormField> dynamicFields = [];

  String pluginKey = "";
  String labelType = "";

  @override
  List<APIFormField> get formFields {
    final baseFields = super.formFields;

    if (pluginKey.isEmpty) {
      // Handle case where default plugin is provided
      final APIFormField pluginField = baseFields.firstWhere(
        (field) => field.name == "plugin",
      );

      if (pluginField.initial_data != null) {
        pluginKey = pluginField.value.toString();
        onValueChanged("plugin", pluginKey);
      }
    }

    return [...baseFields, ...dynamicFields];
  }

  @override
  void onValueChanged(String field, dynamic value) {
    if (field == "plugin") {
      onPluginChanged(value.toString());
    }

    super.onValueChanged(field, value);
  }

  @override
  Future<void> handleSuccess(
    Map<String, dynamic> submittedData,
    Map<String, dynamic> responseData,
  ) async {
    super.handleSuccess(submittedData, responseData);

    // Save default values to the database
    final String? plugin = submittedData["plugin"]?.toString();
    final int? template = submittedData["template"] as int?;

    // Save default printing plugin
    if (plugin != null) {
      InvenTreeSettingsManager().setValue(INV_LABEL_DEFAULT_PLUGIN, plugin);
    }

    // Save default template for this label type
    if (labelType.isNotEmpty && template != null) {
      final defaultTemplates =
          await InvenTreeSettingsManager().getValue(
                INV_LABEL_DEFAULT_TEMPLATES,
                null,
              )
              as Map<String, dynamic>?;

      InvenTreeSettingsManager().setValue(INV_LABEL_DEFAULT_TEMPLATES, {
        ...?defaultTemplates,
        labelType: template,
      });
    }
  }

  /*
   * Re-fetch printing options when the plugin changes
   */
  Future<void> onPluginChanged(String key) async {
    showLoadingOverlay();

    InvenTreeAPI().options(PRINT_LABEL_URL, params: {"plugin": key}).then((
      APIResponse response,
    ) {
      if (response.isValid()) {
        updateFields(response);
        hideLoadingOverlay();
      }
    });
  }

  /*
 * Callback when the server responds with printing options,
 * based on the selected printing plugin
 */
  Future<void> updateFields(APIResponse response) async {
    Map<String, dynamic> printingFields = extractFields(response);

    // Find only the fields which are not in the "base" fields
    List<APIFormField> uniqueFields = [];

    for (String key in printingFields.keys) {
      if (super.formFields.any((field) => field.name == key)) {
        continue;
      }

      dynamic data = printingFields[key];

      Map<String, dynamic> fieldData = {};

      if (data is Map) {
        fieldData = Map<String, dynamic>.from(data);
      }

      APIFormField field = APIFormField(key, fieldData);
      field.definition = extractFieldDefinition(
        printingFields,
        field.lookupPath,
      );

      if (field.type == "dependent field") {
        // Dependent fields must be handled separately

        // TODO: This should be refactored into api_form.dart
        dynamic child = field.definition["child"];

        if (child != null && child is Map) {
          Map<String, dynamic> child_map = child as Map<String, dynamic>;
          dynamic nested_children = child_map["children"];

          if (nested_children != null && nested_children is Map) {
            Map<String, dynamic> nested_child_map =
                nested_children as Map<String, dynamic>;

            for (var field_key in nested_child_map.keys) {
              field = APIFormField(field_key, nested_child_map);
              field.definition = extractFieldDefinition(
                nested_child_map,
                field_key,
              );
              uniqueFields.add(field);
            }
          }
        }
      } else {
        // This is a "standard" (non-nested) field
        uniqueFields.add(field);
      }
    }

    if (mounted) {
      setState(() {
        dynamicFields = uniqueFields;
      });
    }
  }
}

// Maximum number of times to poll the server for print job status
const int PRINT_MAX_POLLS = 60;

// Delay between successive polls of the print job status
const Duration PRINT_POLL_INTERVAL = Duration(seconds: 1);

// Final state of a label print job
enum LabelPrintStatus {
  complete, // Job completed (output may be available for download)
  failed, // Server reported an error, or the job cannot be tracked
  timedOut, // Job did not complete within the polling window
}

class LabelPrintResult {
  const LabelPrintResult(this.status, {this.data = const {}, this.error});

  final LabelPrintStatus status;

  // Most recent DataOutput data received from the server
  final Map<String, dynamic> data;

  // Error message (if available)
  final String? error;

  String get output => (data["output"] ?? "").toString();
}

/*
 * Extract an error message from the "errors" field of a DataOutput object.
 * Returns null if no errors are reported.
 */
String? printOutputError(Map<String, dynamic> data) {
  final dynamic errors = data["errors"];

  if (errors == null) {
    return null;
  }

  dynamic error = errors;

  // e.g. {"error": "message"} or {"field": ["message"]}
  if (error is Map) {
    if (error.isEmpty) return null;
    error = error["error"] ?? error.values.first;
  }

  if (error is List) {
    if (error.isEmpty) return null;
    error = error.first;
  }

  final String message = error.toString().trim();

  return message.isEmpty ? null : message;
}

/*
 * Wait for a label print job (DataOutput) to complete on the server.
 *
 * Polls the job status at [interval], up to [maxPolls] times.
 * Transient request failures are retried until the polling window expires.
 */
Future<LabelPrintResult> waitForPrintOutput(
  Map<String, dynamic> data, {
  Future<APIResponse> Function(String url)? fetch,
  int maxPolls = PRINT_MAX_POLLS,
  Duration interval = PRINT_POLL_INTERVAL,
}) async {
  final request = fetch ?? (String url) => InvenTreeAPI().get(url);

  final int id = (data["pk"] is int) ? data["pk"] as int : -1;

  for (int poll = 0; ; poll++) {
    final String? error = printOutputError(data);

    if (error != null) {
      return LabelPrintResult(
        LabelPrintStatus.failed,
        data: data,
        error: error,
      );
    }

    if (data["complete"] == true) {
      return LabelPrintResult(LabelPrintStatus.complete, data: data);
    }

    if (id <= 0) {
      // No job ID - cannot track progress
      return LabelPrintResult(LabelPrintStatus.failed, data: data);
    }

    if (poll >= maxPolls) {
      return LabelPrintResult(LabelPrintStatus.timedOut, data: data);
    }

    await Future.delayed(interval);

    final APIResponse response = await request("data-output/${id}/");

    if (response.successful() && response.data is Map) {
      data = Map<String, dynamic>.from(response.data as Map);
    } else if (response.isValid() && response.statusCode >= 400) {
      // Client error (e.g. job deleted, or permission denied) - stop polling
      return LabelPrintResult(LabelPrintStatus.failed, data: data);
    }

    // Otherwise (no response or server error), try again
  }
}

/*
 * Handle the server response after a label print request is submitted.
 * Waits for the print job to complete, and notifies the user of the outcome.
 */
Future<void> handlePrintingSuccess(Map<String, dynamic> data) async {
  if (data["complete"] != true && printOutputError(data) == null) {
    // Let the user know that the job has been queued
    showSnackIcon(L10().printLabelInProgress, success: true);
  }

  final LabelPrintResult result = await waitForPrintOutput(data);

  switch (result.status) {
    case LabelPrintStatus.complete:
      if (result.output.isNotEmpty) {
        // An output was generated - we can download it!
        showSnackIcon(L10().downloading, success: true);
        InvenTreeAPI().downloadFile(result.output);
      } else {
        // Label was offloaded, likely to an external printer
        showSnackIcon(L10().printLabelSuccess, success: true);
      }
    case LabelPrintStatus.failed:
      showSnackIcon(
        result.error == null
            ? L10().printLabelFailure
            : "${L10().printLabelFailure}: ${result.error}",
        success: false,
      );
    case LabelPrintStatus.timedOut:
      // Check whether the background worker is processing tasks
      final bool? running = await InvenTreeAPI().refreshWorkerStatus();

      showSnackIcon(
        running == false
            ? L10().printLabelWorkerNotRunning
            : L10().printLabelTimeout,
        success: false,
      );
  }
}

/*
 * Select a particular label, from a provided list of options,
 * and print against the selected instances.
 *
 */
Future<void> selectAndPrintLabel(
  BuildContext context,
  String labelType,
  int instanceId,
) async {
  if (!InvenTreeAPI().isConnected()) {
    return;
  }

  if (!InvenTreeAPI().supportsModernLabelPrinting) {
    // Legacy label printing API not supported
    showSnackIcon("Label printing not supported by server", success: false);
    return;
  }

  // Fetch default values for label printing

  // Default template
  final defaultTemplates = await InvenTreeSettingsManager().getValue(
    INV_LABEL_DEFAULT_TEMPLATES,
    null,
  );
  int? defaultTemplate;

  if (defaultTemplates != null && defaultTemplates is Map<String, dynamic>) {
    defaultTemplate = defaultTemplates[labelType] as int?;
  }

  // Default plugin
  final defaultPlugin = await InvenTreeSettingsManager().getValue(
    INV_LABEL_DEFAULT_PLUGIN,
    null,
  );

  // Specify a default list of fields for printing
  // The selected plugin may optionally extend this list of fields dynamically
  Map<String, Map<String, dynamic>> baseFields = {
    "template": {
      "default": defaultTemplate,
      "filters": {
        "enabled": true,
        "model_type": labelType,
        "items": instanceId.toString(),
      },
    },
    "plugin": {
      "default": defaultPlugin,
      "pk_field": "key",
      "filters": {"enabled": true, "mixin": "labels"},
    },
    "items": {
      "hidden": true,
      "value": [instanceId],
    },
  };

  final formHandler = LabelFormWidgetState();
  formHandler.labelType = labelType;

  launchApiForm(
    context,
    L10().printLabel,
    PRINT_LABEL_URL,
    baseFields,
    method: "POST",
    modelData: {"plugin": defaultPlugin, "template": defaultTemplate},
    formHandler: formHandler,
    onSuccess: (data) async {
      handlePrintingSuccess(data);
    },
  );
}
