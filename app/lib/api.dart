import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

Uri liveSocket(String base, String token) {
  final httpUri = Uri.parse(base);
  final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
  return httpUri.replace(scheme: scheme, path: '/ws', queryParameters: {'token': token});
}

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

class SosApi {
  SosApi({required this.base, this.token});

  final String base;
  final String? token;
  static const _timeout = Duration(seconds: 20);

  Map<String, String> get _auth {
    final current = token;
    if (current == null || current.isEmpty) return {};
    return {'Authorization': 'Bearer $current'};
  }

  Future<void> ping() async {
    final response = await _send((client) => client.get(_uri('/health'), headers: _auth));
    if (response.statusCode != 200) {
      throw ApiException('The server did not respond as SOS Now.', status: response.statusCode);
    }
  }

  Future<({String token, Account account})> register({
    required String name,
    required String phone,
    required String password,
  }) {
    return _authCall('/auth/register', {'name': name, 'phone': phone, 'password': password});
  }

  Future<({String token, Account account})> login({
    required String phone,
    required String password,
  }) {
    return _authCall('/auth/login', {'phone': phone, 'password': password});
  }

  Future<Account> me() async {
    final response = await _send((client) => client.get(_uri('/auth/me'), headers: _auth));
    _expectOk(response);
    return Account.fromJson(_jsonMap(response));
  }

  Future<List<String>> categories() async {
    final response = await _send((client) => client.get(_uri('/categories')));
    _expectOk(response);
    final body = _jsonMap(response);
    final rows = body['categories'];
    if (rows is! List) return defaultCategories;
    return rows.map((item) => item.toString()).toList();
  }

  Future<List<Incident>> incidents({String? category, bool mine = false}) async {
    final response = await _send(
      (client) => client.get(
        _uri('/incidents', {
          if (category != null) 'category': category,
          if (mine) 'mine': 'true',
        }),
        headers: _auth,
      ),
    );
    _expectOk(response);
    return _incidentList(response);
  }

  Future<Incident> incident(int id) async {
    final response = await _send((client) => client.get(_uri('/incidents/$id'), headers: _auth));
    _expectOk(response);
    return Incident.fromJson(_jsonMap(response));
  }

  Future<Incident> createIncident({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required String placeName,
    required Uint8List photo,
    required String filename,
  }) async {
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', _uri('/incidents'));
      request.headers.addAll(_auth);
      request.fields.addAll({
        'category': category,
        'description': description,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'place_name': placeName,
      });
      request.files.add(http.MultipartFile.fromBytes('photo', photo, filename: filename));
      final streamed = await client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      _expectOk(response, created: true);
      return Incident.fromJson(_jsonMap(response));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Can\'t reach the server. Check the address and that this phone is on the same network.');
    } finally {
      client.close();
    }
  }

  Future<List<AlertNote>> notifications() async {
    final response = await _send((client) => client.get(_uri('/notifications'), headers: _auth));
    _expectOk(response);
    final body = jsonDecode(response.body);
    if (body is! List) return [];
    return body.map((item) => AlertNote.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(int id) async {
    final response = await _send((client) => client.post(_uri('/notifications/$id/read'), headers: _auth));
    _expectOk(response);
  }

  Future<void> markAllRead() async {
    final response = await _send((client) => client.post(_uri('/notifications/read-all'), headers: _auth));
    _expectOk(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = Uri.parse(base);
    return root.replace(path: path, queryParameters: query);
  }

  Future<({String token, Account account})> _authCall(String path, Map<String, String> body) async {
    final response = await _send(
      (client) => client.post(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    _expectOk(response, created: path.endsWith('register'));
    final json = _jsonMap(response);
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw ApiException('The server returned an unexpected login response.');
    }
    return (token: json['access_token'] as String, account: Account.fromJson(user));
  }

  Future<T> _send<T>(Future<T> Function(http.Client client) action) async {
    final client = http.Client();
    try {
      return await action(client).timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Can\'t reach the server. Check the address and that this phone is on the same network.');
    } finally {
      client.close();
    }
  }

  List<Incident> _incidentList(http.Response response) {
    final body = jsonDecode(response.body);
    if (body is! List) return [];
    return body.map((item) => Incident.fromJson(item as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _jsonMap(http.Response response) {
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) return body;
    throw ApiException('The server returned an unexpected response.');
  }

  void _expectOk(http.Response response, {bool created = false}) {
    final ok = created ? response.statusCode == 201 : response.statusCode >= 200 && response.statusCode < 300;
    if (ok) return;
    throw ApiException(_detail(response), status: response.statusCode);
  }

  String _detail(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) return first['msg'].toString();
        }
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode}).';
  }
}
