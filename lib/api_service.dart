import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

import 'job_offer.dart';

/// ApiService — centralna warstwa komunikacji z backendem.
/// Zachowuje zgodność z istniejącym interfejsem, dodaje kilka helperów:
/// - suggestCities(query)  -> List<String>
/// - search(params)        -> proxy do fetchOffers
/// - setSearchPrefs(...)   -> lokalne preferencje wyszukiwania
///
/// Nie ruszam mechanizmu autoryzacji (tokeny) — logika została zachowana,
/// ale dopracowałem obsługę błędów, retry po odświeżeniu tokena i cache Hive.
class ApiService extends ChangeNotifier {
  ApiService._(this.baseUrl);

  final String baseUrl;

  static const String registerPath = '/api/register/';
  static const String loginPath = '/api/token/';
  static const String refreshPath = '/api/token/refresh/';
  static const String jobsPath = '/api/jobs/';
  static const String fcmRegisterPath = '/api/fcm/register/';

  final _storage = const FlutterSecureStorage();
  final _messaging = FirebaseMessaging.instance;
  final _connectivity = Connectivity();

  String? _access;
  String? _refresh;
  String? _username;
  bool _online = true;
  bool _notificationsEnabled = true;

  // search preferences (kept in memory; you can persist them via storage if needed)
  int _searchRadiusKm = 25;
  bool _searchRemoteOnly = false;

  final List<JobOffer> _cache = [];
  final List<JobOffer> _savedOffers = [];

  bool get isLoggedIn => (_access != null && _access!.isNotEmpty);
  bool get online => _online;
  bool get notificationsEnabled => _notificationsEnabled;
  String? get username => _username;
  List<JobOffer> get cache => List.unmodifiable(_cache);
  List<JobOffer> get savedOffers => List.unmodifiable(_savedOffers);

  int get searchRadiusKm => _searchRadiusKm;
  bool get searchRemoteOnly => _searchRemoteOnly;

  /// Factory tworzący instancję i inicjalizujący stan (tokens, hive saved offers, fcm).
  static Future<ApiService> create({String? baseUrl}) async {
    final origin = kIsWeb
        ? (baseUrl ?? 'http://127.0.0.1:8000')
        : Platform.isAndroid
            ? (baseUrl ?? 'http://10.0.2.2:8000')
            : (baseUrl ?? 'http://192.168.0.100:8000');

    final svc = ApiService._(origin);

    svc._access = await svc._storage.read(key: 'access');
    svc._refresh = await svc._storage.read(key: 'refresh');
    svc._username = await svc._storage.read(key: 'username');
    final notif = await svc._storage.read(key: 'notifications_enabled');
    svc._notificationsEnabled = (notif?.toLowerCase() == 'true');

    // listen connectivity changes
    svc._connectivity.onConnectivityChanged.listen((r) {
      svc._online = r != ConnectivityResult.none;
      svc.notifyListeners();
    });

    // FCM token refresh
    svc._messaging.onTokenRefresh.listen(svc._onFcmTokenRefresh);

    await svc._initFcm();
    await svc._loadSavedOffersFromHive();

    svc.notifyListeners();
    return svc;
  }

  /// Register new user
  Future<void> register(String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl$registerPath'),
      headers: _defaultHeaders(withJson: true),
      body: utf8.encode(jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      })),
    );
    if (res.statusCode != 201) {
      throw Exception('Rejestracja nieudana: ${res.statusCode} ${utf8.decode(res.bodyBytes)}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    _username = username;
    await _storage.write(key: 'username', value: username);
    await _saveTokens(data['access'], data['refresh']);
  }

  /// Login user and save tokens
  Future<void> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl$loginPath'),
      headers: _defaultHeaders(withJson: true),
      body: utf8.encode(jsonEncode({
        'username': username,
        'password': password,
      })),
    );
    if (res.statusCode != 200) {
      throw Exception('Błąd logowania: ${res.statusCode} ${utf8.decode(res.bodyBytes)}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    _username = username;
    await _storage.write(key: 'username', value: username);
    await _saveTokens(data['access'], data['refresh']);
  }

  Future<void> _saveTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _storage.write(key: 'access', value: access);
    await _storage.write(key: 'refresh', value: refresh);
    notifyListeners();
  }

  /// Logout: clear storage, hive boxes and cached lists
  Future<void> logout() async {
    await _storage.deleteAll();
    _access = null;
    _refresh = null;
    _username = null;

    if (Hive.isBoxOpen('job_offers')) {
      final offersBox = Hive.box<JobOffer>('job_offers');
      await offersBox.clear();
    }
    if (Hive.isBoxOpen('saved_offer_ids')) {
      final savedIds = Hive.box<int>('saved_offer_ids');
      await savedIds.clear();
    }

    _cache.clear();
    _savedOffers.clear();
    notifyListeners();
  }

  /// Refresh access token using refresh token. If refresh fails -> logout.
  Future<void> _refreshAccessToken() async {
    if (_refresh == null || _refresh!.isEmpty) {
      await logout();
      return;
    }
    final res = await http.post(
      Uri.parse('$baseUrl$refreshPath'),
      headers: _defaultHeaders(withJson: true),
      body: utf8.encode(jsonEncode({'refresh': _refresh})),
    );
    if (res.statusCode == 200) {
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      await _saveTokens(d['access'], d['refresh']);
    } else {
      await logout();
    }
  }

  /// Initialize FCM: request permissions, get token, register on backend
  Future<void> _initFcm() async {
    try {
      if (kIsWeb) {
        await _messaging.requestPermission();
      } else if (Platform.isIOS) {
        await _messaging.requestPermission(alert: true, badge: true, sound: true);
      }
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: 'fcm_token', value: token);
        await _registerFcmToken(token);
      }
    } catch (_) {}
  }

  void _onFcmTokenRefresh(String token) async {
    await _storage.write(key: 'fcm_token', value: token);
    await _registerFcmToken(token);
    notifyListeners();
  }

  Future<void> _registerFcmToken(String token) async {
    if (!isLoggedIn) return;
    try {
      await http.post(
        Uri.parse('$baseUrl$fcmRegisterPath'),
        headers: _defaultHeaders(withJson: true),
        body: utf8.encode(jsonEncode({
          'token': token,
          'platform': Platform.operatingSystem,
        })),
      );
    } catch (_) {}
  }

  /// Toggle notifications (subscribe/unsubscribe)
  Future<void> setNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    try {
      if (enabled) {
        await _messaging.subscribeToTopic('jobs');
      } else {
        await _messaging.unsubscribeFromTopic('jobs');
      }
    } catch (_) {}
    await _storage.write(key: 'notifications_enabled', value: enabled.toString());
    notifyListeners();
  }

  /// Set simple search preferences stored in memory; you can persist them if needed.
  void setSearchPrefs({int? radiusKm, bool? remoteOnly}) {
    if (radiusKm != null) _searchRadiusKm = radiusKm;
    if (remoteOnly != null) _searchRemoteOnly = remoteOnly;
    notifyListeners();
  }

  /// Main method to fetch offers from backend with optional filters and caching.
  /// If offline, returns cached Hive box content.
  Future<List<JobOffer>> fetchOffers({
    String? q,
    String? category,
    int? salaryMin,
    int? salaryMax,
    String ordering = '-posted_at',
    int? radiusKm,
    String? city,
  }) async {
    // Ensure the Hive box exists before using
    if (!Hive.isBoxOpen('job_offers')) {
      await Hive.openBox<JobOffer>('job_offers');
    }
    final box = Hive.box<JobOffer>('job_offers');

    if (!_online) {
      _cache
        ..clear()
        ..addAll(box.values);
      notifyListeners();
      return _cache;
    }

    final params = <String, String>{'ordering': ordering};
    if (q?.trim().isNotEmpty == true) params['q'] = q!.trim();
    if (category != null && category.isNotEmpty && category != 'Wszystkie') {
      params['category'] = _mapCategory(category);
    }
    if (salaryMin != null) params['salary_min'] = '$salaryMin';
    if (salaryMax != null) params['salary_max'] = '$salaryMax';
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (radiusKm != null && radiusKm > 0) params['radius_km'] = '$radiusKm';

    final uri = Uri.parse('$baseUrl$jobsPath').replace(queryParameters: params);

    var res = await http.get(uri, headers: _defaultHeaders());
    if (res.statusCode == 401 && _refresh != null && _refresh!.isNotEmpty) {
      await _refreshAccessToken();
      res = await http.get(uri, headers: _defaultHeaders());
    }
    if (res.statusCode != 200) {
      throw Exception('Błąd HTTP ${res.statusCode}: ${utf8.decode(res.bodyBytes)}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    final now = DateTime.now();

    // update local hive cache
    await box.clear();
    _cache
      ..clear()
      ..addAll(data.map((m) => JobOffer.fromMap(m as Map<String, dynamic>, fetchedAt: now)));
    for (final j in _cache) {
      await box.put(j.id, j);
    }

    await _syncSavedWithCache();
    notifyListeners();
    return _cache;
  }

  /// Endpoint to fetch featured offers (used on home)
  Future<List<JobOffer>> fetchFeaturedJobs() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/jobs/featured/'),
      headers: _defaultHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania polecanych ofert: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    final now = DateTime.now();
    return data.map((m) => JobOffer.fromMap(m as Map<String, dynamic>, fetchedAt: now)).toList();
  }

  /// Fetch nearby jobs by coordinates (if backend supports it)
  Future<List<JobOffer>> fetchNearbyJobs({
    required double lat,
    required double lon,
    double radiusKm = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/api/jobs/nearby/').replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'radius_km': '$radiusKm',
    });
    final res = await http.get(uri, headers: _defaultHeaders());
    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania ofert w pobliżu: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    final now = DateTime.now();
    return data.map((m) => JobOffer.fromMap(m as Map<String, dynamic>, fetchedAt: now)).toList();
  }

  /// Fetch cities endpoint (used optionally by advanced search)
  Future<List<Map<String, dynamic>>> fetchCities() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/cities/'),
      headers: _defaultHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania miast: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Suggest cities helper used by AdvancedSearch. Tries backend then returns names list.
  /// Backend expected to return List<Map> or List<String>. We normalize to List<String>.
  Future<List<String>> suggestCities(String query, {int limit = 12}) async {
    // try backend first
    try {
      final uri = Uri.parse('$baseUrl/api/cities/').replace(queryParameters: {'q': query, 'limit': '$limit'});
      final res = await http.get(uri, headers: _defaultHeaders());
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is List) {
          final names = <String>[];
          for (final e in data) {
            if (e is String) names.add(e);
            else if (e is Map && e['name'] != null) names.add(e['name'].toString());
          }
          return names;
        }
      }
    } catch (_) {
      // ignore and fallback to local/hardcoded list handled by caller
    }
    return <String>[];
  }

  /// Proxy search method — wygodny wrapper do wywoływania fetchOffers z mapą parametrów.
  Future<List<JobOffer>> search(Map<String, dynamic> params) async {
    final q = params['q'] as String?;
    final category = params['category'] as String?;
    final salaryMin = params['salary_min'] != null ? int.tryParse(params['salary_min'].toString()) : null;
    final salaryMax = params['salary_max'] != null ? int.tryParse(params['salary_max'].toString()) : null;
    final ordering = params['ordering'] as String? ?? '-posted_at';
    final radiusKm = params['radius_km'] != null ? int.tryParse(params['radius_km'].toString()) : null;
    final city = params['city'] as String?;
    return fetchOffers(q: q, category: category, salaryMin: salaryMin, salaryMax: salaryMax, ordering: ordering, radiusKm: radiusKm, city: city);
  }

  /// Apply to a job (multipart if file provided)
  Future<void> applyToJob(
    int jobId, {
    required String name,
    required String email,
    required String phone,
    String? message,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    if (!isLoggedIn) throw Exception('Zaloguj się, aby aplikować.');
    final uri = Uri.parse('$baseUrl/api/jobs/$jobId/apply/');

    // multipart (file)
    if (fileBytes != null && fileName != null) {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_defaultHeaders())
        ..fields['name'] = name
        ..fields['email'] = email
        ..fields['phone'] = phone;
      if (message != null && message.trim().isNotEmpty) {
        request.fields['message'] = message;
      }
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 201) {
        throw Exception('Nie udało się wysłać aplikacji (${res.statusCode}): ${res.body}');
      }
      return;
    }

    // JSON post
    final res = await http.post(
      uri,
      headers: _defaultHeaders(withJson: true),
      body: utf8.encode(jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        if (message != null && message.trim().isNotEmpty) 'message': message,
      })),
    );
    if (res.statusCode != 201) {
      throw Exception('Nie udało się wysłać aplikacji (${res.statusCode}): ${utf8.decode(res.bodyBytes)}');
    }
  }

  /// Saved offers management backed by Hive box 'saved_offer_ids'
  Future<void> _loadSavedOffersFromHive() async {
    if (!Hive.isBoxOpen('saved_offer_ids')) {
      await Hive.openBox<int>('saved_offer_ids');
    }
    if (!Hive.isBoxOpen('job_offers')) {
      await Hive.openBox<JobOffer>('job_offers');
    }
    final savedIdsBox = Hive.box<int>('saved_offer_ids');
    final ids = savedIdsBox.values.toSet();
    _savedOffers
      ..clear()
      ..addAll(Hive.box<JobOffer>('job_offers').values.where((j) => ids.contains(j.id)));
  }

  Future<void> _syncSavedWithCache() async {
    if (!Hive.isBoxOpen('saved_offer_ids')) return;
    final savedIdsBox = Hive.box<int>('saved_offer_ids');
    final ids = savedIdsBox.values.toSet();
    _savedOffers
      ..clear()
      ..addAll(_cache.where((j) => ids.contains(j.id)));
  }

  bool isSaved(JobOffer o) => _savedOffers.any((e) => e.id == o.id);

  Future<void> saveOffer(JobOffer o) async {
    if (isSaved(o)) return;
    _savedOffers.add(o);
    if (!Hive.isBoxOpen('saved_offer_ids')) {
      await Hive.openBox<int>('saved_offer_ids');
    }
    final savedIdsBox = Hive.box<int>('saved_offer_ids');
    await savedIdsBox.put(o.id, o.id);
    notifyListeners();
  }

  Future<void> removeSaved(JobOffer o) async {
    _savedOffers.removeWhere((e) => e.id == o.id);
    if (!Hive.isBoxOpen('saved_offer_ids')) return;
    final savedIdsBox = Hive.box<int>('saved_offer_ids');
    await savedIdsBox.delete(o.id);
    notifyListeners();
  }

  Map<String, String> _defaultHeaders({bool withJson = false}) {
    final h = <String, String>{'Accept': 'application/json; charset=utf-8'};
    if (withJson) h['Content-Type'] = 'application/json; charset=utf-8';
    if (isLoggedIn) h['Authorization'] = 'Bearer $_access';
    return h;
  }

  String _mapCategory(String c) {
    const map = {
      'IT': 'IT',
      'Medycyna': 'MED',
      'Budownictwo': 'BUILD',
      'Edukacja': 'EDU',
      'Administracja': 'ADMIN',
      'Inne': 'OTHER',
    };
    return map[c] ?? c;
  }
}
