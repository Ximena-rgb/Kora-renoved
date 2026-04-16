import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'services/auth_service.dart';

class ApiClient {
  static const _timeout = Duration(seconds: 20);

  static String get baseUrl =>
      kIsWeb ? dotenv.env['API_URL_WEB']! : dotenv.env['API_URL']!;
  static String get wsUrl =>
      kIsWeb ? dotenv.env['WS_URL_WEB']! : dotenv.env['WS_URL']!;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var r = await http.get(_uri(path, query), headers: await _headers()).timeout(_timeout);
    if (r.statusCode == 401) {
      if (await _refresh()) r = await http.get(_uri(path, query), headers: await _headers()).timeout(_timeout);
    }
    return _handle(r);
  }

  static Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    var r = await http.post(_uri(path), headers: await _headers(),
        body: body != null ? jsonEncode(body) : null).timeout(_timeout);
    if (r.statusCode == 401) {
      if (await _refresh()) r = await http.post(_uri(path), headers: await _headers(),
          body: body != null ? jsonEncode(body) : null).timeout(_timeout);
    }
    return _handle(r);
  }

  static Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    var r = await http.patch(_uri(path), headers: await _headers(),
        body: body != null ? jsonEncode(body) : null).timeout(_timeout);
    if (r.statusCode == 401) {
      if (await _refresh()) r = await http.patch(_uri(path), headers: await _headers(),
          body: body != null ? jsonEncode(body) : null).timeout(_timeout);
    }
    return _handle(r);
  }

  static Future<dynamic> delete(String path) async {
    var r = await http.delete(_uri(path), headers: await _headers()).timeout(_timeout);
    if (r.statusCode == 401) {
      if (await _refresh()) r = await http.delete(_uri(path), headers: await _headers()).timeout(_timeout);
    }
    return _handle(r);
  }

  /// fileArg: List<int> (bytes) en web, String (path) en móvil
  static Future<dynamic> postMultipart(String path, dynamic fileArg, {Map<String, String>? fields}) async {
    final token = await AuthService.getAccessToken();
    final req   = http.MultipartRequest('POST', _uri(path));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    if (fileArg is List<int>) {
      req.files.add(http.MultipartFile.fromBytes('foto', fileArg, filename: 'photo.jpg'));
    } else if (fileArg is String) {
      req.files.add(await http.MultipartFile.fromPath('foto', fileArg));
    }

    if (fields != null) req.fields.addAll(fields);
    final streamed = await req.send().timeout(_timeout);
    final resp     = await http.Response.fromStream(streamed);
    return _handle(resp);
  }

  static Future<bool> _refresh() async => await AuthService.refreshToken() != null;

  static Uri _uri(String path, [Map<String, String>? q]) {
    final uri = Uri.parse('$baseUrl$path');
    return (q != null && q.isNotEmpty) ? uri.replace(queryParameters: q) : uri;
  }

  static dynamic _handle(http.Response r) {
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return body.isEmpty ? null : jsonDecode(body);
    }
    if (r.statusCode == 401) throw ApiException('Sesión expirada.', 401);
    String msg = 'Error (${r.statusCode})';
    try {
      final d = jsonDecode(body);
      if (d is Map) msg = d['error'] ?? d['detail'] ?? msg;
    } catch (_) {}
    if (kDebugMode) print('API ${r.statusCode}: $body');
    throw ApiException(msg, r.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);
  @override String toString() => message;
}
