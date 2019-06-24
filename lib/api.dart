import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;


class InventreeAPI {

  InventreeAPI(this._username, this._password) {
    _secureToken();
  }

  // Base URL for InvenTree API
  String _base_url = "http://10.0.0.7:8000/api/";

  String _username = "";
  String _password = "";

  // Authentication token (initially empty, must be requested)
  String _token = "";

  // Construct an API URL
  String _makeUrl(String url) {
    return path.join(_base_url, url);
  }

  bool _hasToken() {
    return _token.isNotEmpty;
  }

  // Request an API token from the server.
  // A valid username/password combination must be provided
  void _secureToken() async {
    _token = "";

    var _url = _makeUrl("user/token/");
    final response = await http.post(_url,
        body: {
          "username": _username,
          "password": _password
      });

    if (response.statusCode != 200) {
      print("Invalid status code:" + String.fromCharCode(response.statusCode));
    } else {
      var _json = json.decode(response.body);

      if (_json["token"] != null) {
        _token = _json["token"];
        print("Received token: " + _token);
      }
    }
  }

  Future<http.Response> get(String url) async {
    var _url = _makeUrl(url);
    final response = await http.get(_url,
      headers: {
          HttpHeaders.authorizationHeader: "Token: " + _token
        }
    );

    print("Making request to " + _url);
    print(response.statusCode);
    print(response.body);

    return response;
  }

}