import 'package:inventree/inventree/part.dart';
import 'package:inventree/widget/refreshable_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:inventree/l10.dart';


class PartNotesWidget extends StatefulWidget {

  final InvenTreePart part;

  PartNotesWidget(this.part, {Key? key}) : super(key: key);

  @override
  _PartNotesState createState() => _PartNotesState(part);
}


class _PartNotesState extends RefreshableState<PartNotesWidget> {

  final InvenTreePart part;

  _PartNotesState(this.part);

  @override
  String getAppBarTitle(BuildContext context) => L10().partNotes;

  @override
  Widget getBody(BuildContext context) {
    return Markdown(
      selectable: false,
      data: part.notes,
    );
  }

}