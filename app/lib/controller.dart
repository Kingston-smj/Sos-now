import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';

class SosController extends ChangeNotifier {
  String apiBase = 'http://127.0.0.1:8000';
  String? token;
  String? name;
  String? phone;
  bool ready = false;
  bool busy = false;
  String? error;
  String? selectedCategory;
  String? liveMessage;
  int? liveIncidentId;
  List<String> categories = defaultCategories;
  List<Incident> feed = [];
  List<Incident> mine = [];
  List<AlertNote> alerts = [];

  bool _live = false;
  int _generation = 0;
  Timer? _poll;
  Timer? _reconnect;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Set<int> _seenAlertIds = {};

  int get unread => alerts.where((note) => !note.read).length;

  SosApi _api() => SosApi(base: apiBase, token: token);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedBase = prefs.getString('api_base');
    if (storedBase != null && storedBase.isNotEmpty) apiBase = storedBase;
    token = prefs.getString('token');
    name = prefs.getString('name');
    phone = prefs.getString('phone');
    ready = true;
    notifyListeners();
    if (token != null) {
      await refreshAll();
      if (token != null) startLive();
    }
  }

  Future<bool> register({
    required String base,
    required String personName,
    required String phoneNumber,
    required String password,
  }) {
    return _signIn(
      base: base,
      call: (api) => api.register(name: personName, phone: phoneNumber, password: password),
    );
  }

  Future<bool> login({
    required String base,
    required String phoneNumber,
    required String password,
  }) {
    return _signIn(
      base: base,
      call: (api) => api.login(phone: phoneNumber, password: password),
    );
  }

  Future<bool> _signIn({
    required String base,
    required Future<({String token, Account account})> Function(SosApi api) call,
  }) async {
    apiBase = normalizeBase(base);
    await _saveBase();
    busy = true;
    error = null;
    notifyListeners();
    try {
      final session = await call(SosApi(base: apiBase));
      await _keep(session.token, session.account);
      await refreshAll();
      if (token != null) startLive();
      return token != null;
    } on ApiException catch (err) {
      error = err.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _stopLive();
    token = null;
    name = null;
    phone = null;
    feed = [];
    mine = [];
    alerts = [];
    liveMessage = null;
    error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('name');
    await prefs.remove('phone');
    notifyListeners();
  }

  Future<void> refreshAll() async {
    try {
      final api = _api();
      final account = await api.me();
      name = account.name;
      phone = account.phone;
      categories = await api.categories();
      feed = await api.incidents(category: selectedCategory);
      mine = await api.incidents(mine: true);
      final notes = await api.notifications();
      _seenAlertIds = notes.map((note) => note.id).toSet();
      alerts = notes;
      error = null;
    } on ApiException catch (err) {
      if (err.status == 401) {
        await logout();
        return;
      }
      error = err.message;
    }
    notifyListeners();
  }

  Future<void> refreshFeed() async {
    try {
      feed = await _api().incidents(category: selectedCategory);
      error = null;
      notifyListeners();
    } on ApiException catch (err) {
      _keepError(err);
    }
  }

  Future<void> refreshMine() async {
    try {
      mine = await _api().incidents(mine: true);
      error = null;
      notifyListeners();
    } on ApiException catch (err) {
      _keepError(err);
    }
  }

  Future<void> selectCategory(String? category) async {
    selectedCategory = category;
    notifyListeners();
    await refreshFeed();
  }

  Future<Incident> submit({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required String placeName,
    required Uint8List photo,
    required String filename,
  }) async {
    final created = await _api().createIncident(
      category: category,
      description: description,
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      photo: photo,
      filename: filename,
    );
    await refreshFeed();
    await refreshMine();
    return created;
  }

  Future<Incident> fetchIncident(int id) => _api().incident(id);

  Future<void> refreshAlerts({bool announce = false}) async {
    try {
      final notes = await _api().notifications();
      if (announce) {
        final fresh = notes.where((note) => !note.read && !_seenAlertIds.contains(note.id)).toList();
        if (fresh.isNotEmpty) {
          liveMessage = fresh.first.message;
          liveIncidentId = fresh.first.incidentId;
        }
      }
      _seenAlertIds = notes.map((note) => note.id).toSet();
      alerts = notes;
      notifyListeners();
    } on ApiException catch (err) {
      _keepError(err);
    }
  }

  Future<void> markRead(int id) async {
    await _api().markRead(id);
    await refreshAlerts();
  }

  Future<void> markAllRead() async {
    await _api().markAllRead();
    await refreshAlerts();
  }

  void dismissLive() {
    liveMessage = null;
    liveIncidentId = null;
    notifyListeners();
  }

  void startLive() {
    _stopLive();
    if (token == null) return;
    _live = true;
    _connect();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => refreshAlerts(announce: true));
  }

  void _connect() {
    if (!_live || token == null) return;
    final generation = ++_generation;
    _subscription?.cancel();
    _channel?.sink.close();
    try {
      final channel = WebSocketChannel.connect(liveSocket(apiBase, token!));
      _channel = channel;
      _subscription = channel.stream.listen(
        _onSocketMessage,
        onError: (_, __) {
          if (_live && generation == _generation) _scheduleReconnect();
        },
        onDone: () {
          if (_live && generation == _generation) _scheduleReconnect();
        },
      );
    } catch (_) {
      if (_live && generation == _generation) _scheduleReconnect();
    }
  }

  void _onSocketMessage(Object? event) {
    try {
      final text = switch (event) {
        String value => value,
        List<int> value => utf8.decode(value),
        _ => null,
      };
      if (text == null) return;
      final data = jsonDecode(text);
      if (data is! Map || data['type'] != 'incident.created') return;
      liveMessage = data['message']?.toString() ?? 'A new incident was reported';
      final rawId = data['incident_id'];
      liveIncidentId = rawId is int ? rawId : int.tryParse('$rawId');
      notifyListeners();
      refreshFeed();
      refreshAlerts(announce: true);
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (!_live) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), _connect);
  }

  void _stopLive() {
    _live = false;
    _generation++;
    _poll?.cancel();
    _reconnect?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _keepError(ApiException err) {
    if (err.status == 401) {
      logout();
      return;
    }
    error = err.message;
    notifyListeners();
  }

  Future<void> _keep(String accessToken, Account account) async {
    token = accessToken;
    name = account.name;
    phone = account.phone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', accessToken);
    await prefs.setString('name', account.name);
    await prefs.setString('phone', account.phone);
  }

  Future<void> _saveBase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base', apiBase);
  }

  @override
  void dispose() {
    _stopLive();
    super.dispose();
  }
}
