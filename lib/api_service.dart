import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';
import 'user.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          (baseUrl ??
                  (const String.fromEnvironment('API_BASE_URL').isNotEmpty
                      ? const String.fromEnvironment('API_BASE_URL')
                      : kIsWeb
                      ? 'http://localhost:8081'
                      : 'http://10.0.2.2:8081'))
              .replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;
  String? _sessionToken;

  Future<User> login(String email, String password) async {
    final data = await _send(
      'POST',
      '/login',
      body: {'email': email, 'password': password},
    );
    if (data is! Map<String, dynamic> || data['id'] == null) {
      throw const ApiException('Adresse e-mail ou mot de passe incorrect.');
    }
    final user = User.fromMap(data);
    _sessionToken = data['token']?.toString();
    return user;
  }

  Future<User> register(String email, String password) async {
    final data = await _send(
      'POST',
      '/register',
      body: {'email': email, 'password': password},
    );
    if (data is! Map<String, dynamic> || data['id'] == null) {
      throw const ApiException(
        'Le serveur n’a pas confirmé la création du compte.',
      );
    }
    return User.fromMap(data);
  }

  Future<void> logout() async {
    try {
      if (_sessionToken != null) await _send('POST', '/logout');
    } finally {
      _sessionToken = null;
    }
  }

  Future<List<Classroom>> getClasses() async =>
      _list('/classes', Classroom.fromMap);
  Future<List<Map<String, dynamic>>> getDepartments() =>
      tp7List('/tp7/departements');
  Future<List<Training>> getTrainings() async =>
      _list('/formations', Training.fromMap);
  Future<List<Student>> getStudents() async =>
      _list('/etudiants', Student.fromMap);

  Future<void> saveClass(Classroom value, {String? oldCode}) async => _send(
    oldCode == null ? 'POST' : 'PUT',
    oldCode == null ? '/classes' : '/classes/${Uri.encodeComponent(oldCode)}',
    body: value.toMap(),
  );
  Future<void> deleteClass(String code) async =>
      _send('DELETE', '/classes/${Uri.encodeComponent(code)}');
  Future<void> saveTraining(Training value, {int? id}) async => _send(
    id == null ? 'POST' : 'PUT',
    id == null ? '/formations' : '/formations/$id',
    body: value.toMap(),
  );
  Future<void> deleteTraining(int id) async =>
      _send('DELETE', '/formations/$id');
  Future<void> saveStudent(Student value, {int? id}) async => _send(
    id == null ? 'POST' : 'PUT',
    id == null ? '/etudiants' : '/etudiants/$id',
    body: value.toMap(),
  );
  Future<void> deleteStudent(int id) async => _send('DELETE', '/etudiants/$id');

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final data = await _send('GET', path);
    if (data is! List) {
      throw const ApiException('Format de réponse inattendu du serveur.');
    }
    return data
        .whereType<Map>()
        .map((item) => parse(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json';
      if (_sessionToken != null) {
        request.headers['Authorization'] = 'Bearer $_sessionToken';
      }
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_errorMessage(response));
      }
      if (response.body.trim().isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on ApiException {
      rethrow;
    } on Exception catch (error) {
      final cause = kIsWeb
          ? 'Vérifiez que le backend fonctionne et que son CORS autorise cette adresse Chrome.'
          : 'Vérifiez que le backend fonctionne et que son adresse est correcte.';
      throw ApiException(
        'Connexion impossible vers $baseUrl (${error.runtimeType}). $cause',
      );
    }
  }

  String _errorMessage(http.Response response) {
    final fromBody = _messageFromBody(response.body);
    if (fromBody != null) return fromBody;
    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Identifiants invalides ou accès refusé.';
    }
    if (response.statusCode == 404) {
      return 'Service introuvable (${response.request?.url.path}). Vérifiez les routes du backend.';
    }
    if (response.statusCode == 409) return 'Cette donnée existe déjà.';
    return 'Erreur du serveur (${response.statusCode}).';
  }

  String? _messageFromBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['message'] is String) {
        final message = (decoded['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> tp7List(String path) async {
    final value = await _send('GET', path);
    if (value is! List) {
      throw const ApiException('Format de réponse inattendu.');
    }
    return value
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  Future<Map<String, dynamic>> tp7Get(String path) async {
    final value = await _send('GET', path);
    if (value is! Map) throw const ApiException('Format de réponse inattendu.');
    return Map<String, dynamic>.from(value);
  }

  Future<Map<String, dynamic>> tp7Save(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    final value = await _send(method, path, body: body);
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  Future<void> tp7Delete(String path) async {
    await _send('DELETE', path);
  }
}
