import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;


class InvenTreeAPI {

  static const _URL_GET_TOKEN = "user/token/";

  // Ensure we only ever create a single instance of the API class
  static final InvenTreeAPI _api = new InvenTreeAPI._internal();

  factory InvenTreeAPI() {
    return _api;
  }

  InvenTreeAPI._internal();

  void connect(String address, String username, String password) async {

    address = address.trim();
    username = username.trim();

    if (!address.endsWith("api/") || !address.endsWith("api")) {
      address = path.join(address, "api");
    }

    if (!address.endsWith('/')) {
      address = address + '/';
    }

    _base_url = address;
    _username = username;
    _password = password;

    _connected = false;

    print("Connecting to " + address + " -> " + username + ":" + password);

    await _tryConnection();

    await _secureToken();
  }

  bool _connected = false;

  // Base URL for InvenTree API
  String _base_url = "http://127.0.0.1:8000/api/";

  String _username = "";
  String _password = "";

  // Authentication token (initially empty, must be requested)
  String _token = "";

  // Construct an API URL
  String _makeUrl(String url) {

    if (url.startsWith('/')) {
      url = url.substring(1);
    }

    return path.join(_base_url, url);
  }

  bool _hasToken() {
    return _token.isNotEmpty;
  }

  // Request the raw /api/ endpoing to see if there is an InvenTree server listening
  void _tryConnection() async {

    print("Testing connection to server");

    final response = await get("").then((http.Response response) {
      print("response!");
      print(response.body);
    }).catchError((error) {
      print("Error trying connection");
    });

    // TODO - Add timeout handler
  }

  // Request an API token from the server.
  // A valid username/password combination must be provided
  void _secureToken() async {
    if (_token.isNotEmpty) {
      print("Discarding old token - " + _token);
    }
    _token = "";

    var response = post(_URL_GET_TOKEN,
        body: {
          "username": _username,
          "password": _password,
        });

    response.then((http.Response response) {
      if (response.statusCode != 200) {
        print("Invalid status code: " + response.statusCode.toString());
      } else {
        var _json = json.decode(response.body);

        if (_json["token"] != null) {
          _token = _json["token"];
          print("Received token: " + _token);
        }
      }
    }).catchError((error) {
      print("Error retrieving token");
    });
  }

  // Perform a PATCH request
  Future<http.Response> patch(String url, {Map<String, String> body}) async {

    var _url = _makeUrl(url);
    var _headers = _defaultHeaders();
    var _body = Map<String, String>();

    // Copy across provided data
    body.forEach((K, V) => _body[K] = V);

    print("PATCH: " + _url);

    final response = await http.patch(_url,
      headers: _headers,
      body: _body,
    );

    return response;
  }

  // Perform a POST request
  Future<http.Response> post(String url, {Map<String, String> body}) async {

    var _url = _makeUrl(url);
    var _headers = _defaultHeaders();
    var _body = Map<String, String>();

    // Copy across provided data
    body.forEach((K, V) => _body[K] = V);

    print("POST: " + _url);

    final response = await http.post(_url,
      headers: _headers,
      body: _body,
    );

    return response;
  }

  // Perform a GET request
  Future<http.Response> get(String url) async {

    var _url = _makeUrl(url);
    var _headers = _defaultHeaders();

    print("GET: " + _url);

    final response = await http.get(_url,
      headers: _headers,
    );

    return response;
  }

  Map<String, String> _defaultHeaders() {

    var headers = Map<String, String>();

    if (_token.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = "Token " + _token;
    }

    return headers;
  }

}