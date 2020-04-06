
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/company.dart';
import 'package:InvenTree/widget/drawer.dart';

class CompanyListWidget extends StatefulWidget {

  @override
  _CompanyListState createState() => _CompanyListState();

}


class _CompanyListState extends State<CompanyListWidget> {

  var _companies = new List<InvenTreeCompany>();

  var _filteredCompanies = new List<InvenTreeCompany>();

  var _title = "Companies";

  _CompanyListState() {
    _requestData();
  }

  void _requestData() {

    InvenTreeCompany().list().then((var companies) {

      _companies.clear();

      for (var c in companies) {
        if (c is InvenTreeCompany) {
          _companies.add(c);
        }
      }

      setState(() {
        _filterResults("");
      });

    });
  }

  void _filterResults(String text) {

    if (text.isEmpty) {
      _filteredCompanies = _companies;
    } else {
      _filteredCompanies = _companies.where((c) => c.filter(text)).toList();
    }
  }

  Widget _showCompany(BuildContext context, int index) {

      InvenTreeCompany company = _filteredCompanies[index];

      return ListTile(
        title: Text("${company.name}"),
        subtitle: Text("${company.description}"),
        leading: Image(
            image: InvenTreeAPI().getImage(company.image),
            width: 40,
        ),
        onTap: () {
          if (company.pk > 0) {
            InvenTreeCompany().get(company.pk).then((var c) {
              print("Retrieved company: ${c.name}");
            });
          }
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("$_title"),
        ),
        drawer: new InvenTreeDrawer(context),
        body: ListView(
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
              hintText: 'Filter results',
              ),
              onChanged: (String text) {
                setState(() {
                  _filterResults(text);
                });
              },
            ),
            ListView.builder(
              shrinkWrap: true,
                physics: ClampingScrollPhysics(),
                itemBuilder: _showCompany, itemCount: _filteredCompanies.length)
          ],
        )
    );
  }

}