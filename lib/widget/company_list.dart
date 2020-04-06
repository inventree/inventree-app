
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/company.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

abstract class CompanyListWidget extends StatefulWidget {

  String title;
  Map<String, String> filters;

  @override
  _CompanyListState createState() => _CompanyListState(title, filters);

}

class SupplierListWidget extends CompanyListWidget {
  @override
  _CompanyListState createState() => _CompanyListState("Suppliers", {"is_supplier": "true"});
}


class CustomerListWidget extends CompanyListWidget {
  @override
  _CompanyListState createState() => _CompanyListState("Customers", {"is_customer": "true"});
}


class _CompanyListState extends State<CompanyListWidget> {

  var _companies = new List<InvenTreeCompany>();

  var _filteredCompanies = new List<InvenTreeCompany>();

  var _title = "Companies";

  Map<String, String> _filters = Map<String, String>();

  _CompanyListState(this._title, this._filters) {
    _requestData();
  }

  void _requestData() {

    InvenTreeCompany().list(filters: _filters).then((var companies) {

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
          actions: <Widget>[
            IconButton(
              icon: FaIcon(FontAwesomeIcons.plus),
              tooltip: 'New',
              onPressed: null,
            )
          ],
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