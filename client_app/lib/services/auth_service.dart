import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _storage = FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<Map<String, dynamic>> authenticate({
    required bool register,
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/auth/${register ? 'register' : 'login'}',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (register) 'name': name,
        'email': email,
        'password': password,
      }),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Could not authenticate');
    }

    final data = Map<String, dynamic>.from(payload['data'] as Map);
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw Exception('The server did not return an authentication token');
    }
    await saveToken(token);
    return data;
  }
}
