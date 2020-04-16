
import 'package:InvenTree/widget/company_detail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:InvenTree/api.dart';
import 'package:InvenTree/inventree/company.dart';
import 'package:InvenTree/widget/drawer.dart';
import 'package:InvenTree/widget/refreshable_state.dart';
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


class _CompanyListState extends RefreshableState<CompanyListWidget> {

  var _companies = new List<InvenTreeCompany>();

  var _filteredCompanies = new List<InvenTreeCompany>();

  String _title = "Companies";

  @override
  String getAppBarTitle(BuildContext context) { return _title; }

  Map<String, String> _filters = Map<String, String>();

  _CompanyListState(this._title, this._filters) {}

  @override
  Future<void> onBuild(BuildContext context) async {
    refresh();
  }

  @override
  Future<void> request(BuildContext context) async {

    InvenTreeCompany().list(context, filters: _filters).then((var companies) {

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
            InvenTreeCompany().get(context, company.pk).then((var c) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyDetailWidget(c)));
            });
          }
        },
      );
  }

  @override
  Widget getBody(BuildContext context) {
    return ListView(
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
    );
  }
}