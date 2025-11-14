

import "package:flutter/cupertino.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/refreshable_state.dart";

class PrintLabelWidget extends StatefulWidget {
  const PrintLabelWidget({Key? key}) : super(key: key);

  @override
  _PrintLabelWidgetState createState() => _PrintLabelWidgetState();
}


class _PrintLabelWidgetState extends RefreshableState<PrintLabelWidget> {

  @override
  String getAppBarTitle() => L10().printLabel;

  @override
  List<Widget> appBarActions(BuildContext context) {
    List<Widget> actions = [];

    // TODO: Add actions here

    return actions;
  }

  @override
  Widget getBody(BuildContext context) {
    return Container();
  }
}