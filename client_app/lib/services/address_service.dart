import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class AddressService {
  Future<List<Map<String, dynamic>>> getAddresses(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(response);
    return List<Map<String, dynamic>>.from(
      payload['data'] as List? ?? const [],
    );
  }

  Future<Map<String, dynamic>> createAddress(
    String token,
    Map<String, dynamic> address,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses'),
      headers: _headers(token),
      body: jsonEncode(address),
    );
    final payload = _decodeResponse(response);
    return Map<String, dynamic>.from(payload['data'] as Map);
  }

  Future<Map<String, dynamic>> setDefault(String token, int addressId) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses/$addressId/default'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(response);
    return Map<String, dynamic>.from(payload['data'] as Map);
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Address request failed');
    }
    return payload;
  }
}
