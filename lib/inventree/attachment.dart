import "dart:io";

import "package:flutter/cupertino.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/api.dart";
import "package:inventree/inventree/model.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/fields.dart";
import "package:inventree/widget/snacks.dart";
import "package:path/path.dart" as path;

class InvenTreeAttachment extends InvenTreeModel {
  // Class representing an "attachment" file
  InvenTreeAttachment() : super();

  InvenTreeAttachment.fromJson(Map<String, dynamic> json)
    : super.fromJson(json);

  @override
  InvenTreeAttachment createFromJson(Map<String, dynamic> json) => InvenTreeAttachment.fromJson(json);

  @override
  String get URL => "attachment/";

  @override
  Map<String, Map<String, dynamic>> formFields() {
    Map<String, Map<String, dynamic>> fields = {"link": {}, "comment": {}};

    if (!hasLink) {
      fields.remove("link");
    }

    return fields;
  }

  // The model type of the instance this attachment is associated with
  String get modelType => getString("model_type");

  // The ID of the instance this attachment is associated with
  int get modelId => getInt("model_id");

  String get attachment => getString("attachment");

  bool get hasAttachment => attachment.isNotEmpty;

  // Return the filename of the attachment
  String get filename {
    return attachment.split("/").last;
  }

  IconData get icon {
    String fn = filename.toLowerCase();

    if (fn.endsWith(".pdf")) {
      return TablerIcons.file_type_pdf;
    } else if (fn.endsWith(".csv")) {
      return TablerIcons.file_type_csv;
    } else if (fn.endsWith(".doc") || fn.endsWith(".docx")) {
      return TablerIcons.file_type_doc;
    } else if (fn.endsWith(".xls") || fn.endsWith(".xlsx")) {
      return TablerIcons.file_type_xls;
    }

    // Image formats
    final List<String> img_formats = [".png", ".jpg", ".gif", ".bmp", ".svg"];

    for (String fmt in img_formats) {
      if (fn.endsWith(fmt)) {
        return TablerIcons.file_type_jpg;
      }
    }

    return TablerIcons.file;
  }

  String get comment => getString("comment");

  DateTime? get uploadDate {
    if (jsondata.containsKey("upload_date")) {
      return DateTime.tryParse((jsondata["upload_date"] ?? "") as String);
    } else {
      return null;
    }
  }

  // Return a count of how many attachments exist against the specified model ID
  Future<int> countAttachments(String modelType, int modelId) {
    Map<String, String> filters = {};

    filters["model_type"] = modelType;
    filters["model_id"] = modelId.toString();

    return count(filters: filters);
  }

  Future<bool> uploadAttachment(
    File attachment,
    String modelType,
    int modelId, {
    String comment = "",
    Map<String, String> fields = const {},
  }) async {
    // Ensure that the correct reference field is set
    Map<String, String> data = Map<String, String>.from(fields);

    String url = URL;

    if (comment.isNotEmpty) {
      data["comment"] = comment;
    }

    data["model_type"] = modelType;
    data["model_id"] = modelId.toString();

    final APIResponse response = await InvenTreeAPI().uploadFile(
      url,
      attachment,
      method: "POST",
      name: "attachment",
      fields: data,
    );

    return response.successful();
  }

  Future<bool> uploadImage(
    String modelType,
    int modelId, {
    String prefix = "InvenTree",
  }) async {
    bool result = false;

    await FilePickerDialog.pickImageFromCamera().then((File? file) {
      if (file != null) {
        String dir = path.dirname(file.path);
        String ext = path.extension(file.path);
        String now = DateTime.now().toIso8601String().replaceAll(":", "-");

        // Rename the file with a unique name
        String filename = "${dir}/${prefix}_image_${now}${ext}";

        try {
          file.rename(filename).then((File renamed) {
            uploadAttachment(renamed, modelType, modelId).then((success) {
              result = success;
              showSnackIcon(
                result ? L10().imageUploadSuccess : L10().imageUploadFailure,
                success: result,
              );
            });
          });
        } catch (error, stackTrace) {
          sentryReportError("uploadImage", error, stackTrace);
          showSnackIcon(L10().imageUploadFailure, success: false);
        }
      }
    });

    return result;
  }

  /*
   * Download this attachment file
   */
  Future<void> downloadAttachment() async {
    await InvenTreeAPI().downloadFile(attachment);
  }
}
