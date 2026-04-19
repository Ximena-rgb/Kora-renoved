import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  static const _accessKey  = 'kora_access_token';
  static const _refreshKey = 'kora_refresh_token';

  static String get _baseUrl =>
      kIsWeb ? dotenv.env['API_URL_WEB']! : dotenv.env['API_URL']!;

  static Map<String, dynamic> _decodeSafe(http.Response resp) {
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'detail': decoded.toString()};
    } catch (_) {
      final bodyText = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      return {
        'detail': bodyText.isNotEmpty
            ? bodyText
            : 'Respuesta no JSON del servidor (${resp.statusCode}).',
      };
    }
  }

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    ).timeout(const Duration(seconds: 20));

    final data = _decodeSafe(resp);
    if (resp.statusCode == 200 && data['access'] != null) {
      await saveTokens(data['access'], data['refresh']);
    }
    return {'status': resp.statusCode, ...data};
  }

  static Future<String?> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return null;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/v1/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await saveTokens(data['access'], data['refresh'] ?? refresh);
        return data['access'];
      }
    } catch (_) {}
    return null;
  }

  static Future<void> logout() async {
    final refresh = await getRefreshToken();
    final access  = await getAccessToken();
    if (refresh != null && access != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/v1/auth/logout/'),
          headers: {'Content-Type': 'application/json',
                    'Authorization': 'Bearer $access'},
          body: jsonEncode({'refresh': refresh}),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  static Future<Map<String, dynamic>> loginWithEmail(
      String email, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/debug/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeSafe(resp);
    if (resp.statusCode == 200 && data['access'] != null) {
      await saveTokens(data['access'], data['refresh']);
    }
    return {'status': resp.statusCode, ...data};
  }

  static Future<Map<String, dynamic>> register(
      String email, String password, String nombre) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/debug/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'nombre': nombre}),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeSafe(resp);
    if ((resp.statusCode == 200 || resp.statusCode == 201) && data['access'] != null) {
      await saveTokens(data['access'], data['refresh']);
    }
    return {'status': resp.statusCode, ...data};
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/password-reset/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeSafe(resp);
    return {'status': resp.statusCode, ...data};
  }

  static Future<Map<String, dynamic>> confirmPasswordReset(
      String email, String code, String newPassword) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/password-reset/confirm/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email':        email,
        'code':         code,
        'new_password': newPassword,
      }),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeSafe(resp);
    return {'status': resp.statusCode, ...data};
  }
}
