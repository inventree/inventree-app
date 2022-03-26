import "package:inventree/inventree/part.dart";
import "package:inventree/widget/part_detail.dart";
import "package:inventree/widget/progress.dart";
import "package:inventree/widget/refreshable_state.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";

import "package:inventree/l10.dart";

import "package:inventree/api.dart";


class StarredPartWidget extends StatefulWidget {

  const StarredPartWidget({Key? key}) : super(key: key);

  @override
  _StarredPartState createState() => _StarredPartState();
}


class _StarredPartState extends RefreshableState<StarredPartWidget> {

  List<InvenTreePart> starredParts = [];

  @override
  String getAppBarTitle(BuildContext context) => L10().partsStarred;

  @override
  Future<void> request(BuildContext context) async {

    final parts = await InvenTreePart().list(filters: {"starred": "true"});

    starredParts.clear();

    for (int idx = 0; idx < parts.length; idx++) {
      if (parts[idx] is InvenTreePart) {
        starredParts.add(parts[idx] as InvenTreePart);
      }
    }
  }

  Widget _partResult(BuildContext context, int index) {
    final part = starredParts[index];

    return ListTile(
        title: Text(part.fullname),
        subtitle: Text(part.description),
        leading: InvenTreeAPI().getImage(
            part.thumbnail,
            width: 40,
            height: 40
        ),
        onTap: () {
          InvenTreePart().get(part.pk).then((var prt) {
            if (prt is InvenTreePart) {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PartDetailWidget(prt))
              );
            }
          });
        }
    );
  }

  @override
  Widget getBody(BuildContext context) {

    if (loading) {
      return progressIndicator();
    }

    if (starredParts.isEmpty) {
      return ListView(
        children: [
          ListTile(
            title: Text(L10().partsNone),
            subtitle: Text(L10().partsStarredNone)
          )
        ],
      );
    }

    return ListView.separated(
      itemCount: starredParts.length,
      itemBuilder: _partResult,
      separatorBuilder: (_, __) => const Divider(height: 3),
      physics: ClampingScrollPhysics(),
    );
  }
}