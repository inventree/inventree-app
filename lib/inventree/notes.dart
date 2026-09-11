import "package:inventree/inventree/model.dart";

/*
 * Class representing a single "note" entry.
 *
 * Notes can be attached to any model instance which supports the
 * InvenTree "multi notes" API - multiple notes may be attached to
 * a single model instance.
 *
 * Note content is provided by the server as editor-agnostic HTML,
 * and cannot be edited from within this app.
 *
 * Ref: https://github.com/inventree/InvenTree/pull/11971
 */
class InvenTreeNoteEntry extends InvenTreeModel {
  InvenTreeNoteEntry() : super();

  InvenTreeNoteEntry.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  InvenTreeNoteEntry createFromJson(Map<String, dynamic> json) =>
      InvenTreeNoteEntry.fromJson(json);

  @override
  String get URL => "note/";

  // The model type of the instance this note is associated with
  String get modelType => getString("model_type");

  // The ID of the instance this note is associated with
  int get modelId => getInt("model_id");

  String get title => getString("title");

  // Rendered (HTML) content of this note
  String get content => getString("content");

  DateTime? get updated => getDate("updated");
}
