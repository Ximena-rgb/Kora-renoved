import 'package:flutter/material.dart';
import 'api_client.dart';

// Helper que convierte num o String a double de forma segura
double _toDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

// Helper que convierte num o String a int de forma segura
int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class CandidatoModel {
  final int id;
  final String nombre;
  final String? fotoUrl;
  final String carrera;
  final String facultad;
  final int semestre;
  final double reputacion;
  final String bioCorta;
  final List<String> gustos;
  final int? edad;
  final double scoreTotal;
  final List<Map<String, dynamic>> fotos;

  CandidatoModel.fromJson(Map<String, dynamic> j)
    : id          = j['id'],
      nombre      = j['nombre'] ?? '',
      fotoUrl     = j['foto_url'],
      carrera     = j['carrera'] ?? '',
      facultad    = j['facultad'] ?? '',
      semestre    = _toInt(j['semestre'], 1),
      reputacion  = _toDouble(j['reputacion']),
      bioCorta    = j['bio_corta'] ?? '',
      gustos      = List<String>.from(j['gustos'] ?? []),
      edad        = j['edad'],
      scoreTotal  = _toDouble(j['score_total']),
      fotos       = List<Map<String, dynamic>>.from(j['fotos'] ?? []);
}

class MatchModel {
  final int id;
  final String modo;
  final double score;
  final int? conversacionId;
  final Map<String, dynamic>? otroUsuario;
  final String createdAt;

  MatchModel.fromJson(Map<String, dynamic> j)
    : id             = j['id'],
      modo           = j['modo'] ?? '',
      score          = _toDouble(j['score']),
      conversacionId = j['conversacion_id'],
      otroUsuario    = j['otro_usuario'],
      createdAt      = j['created_at'] ?? '';
}

class MatchingProvider with ChangeNotifier {
  List<CandidatoModel> _deck        = [];
  List<Map<String, dynamic>> _likes = [];
  List<MatchModel> _matches         = [];
  String _modo      = 'pareja';
  bool _loading     = false;
  String? _error;
  Map<String, dynamic>? _likesInfo;

  List<CandidatoModel> get deck     => _deck;
  List<Map<String, dynamic>> get likes => _likes;
  List<MatchModel> get matches      => _matches;
  String get modo                   => _modo;
  bool get loading                  => _loading;
  String? get error                 => _error;
  Map<String, dynamic>? get likesInfo => _likesInfo;

  void setModo(String m) { _modo = m; cargarDeck(); }

  Future<void> cargarDeck() async {
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await ApiClient.get('/api/v1/matching/deck/', query: {'modo': _modo});
      _deck     = (data['candidatos'] as List).map((c) => CandidatoModel.fromJson(c)).toList();
      _likesInfo = data['likes_restantes'] is Map ? data['likes_restantes'] : null;
    } on ApiException catch (e) { _error = e.message; }
    _loading = false; notifyListeners();
  }

  Future<Map<String, dynamic>?> swipe(int userId, String accion, {bool superlike = false}) async {
    try {
      final data = await ApiClient.post('/api/v1/matching/swipe/', body: {
        'a_usuario_id': userId,
        'modo':         _modo,
        'accion':       accion,
        'es_superlike': superlike,
      });
      _likesInfo = data['likes_restantes'] is Map ? data['likes_restantes'] : null;
      // Quitar del deck
      _deck.removeWhere((c) => c.id == userId);
      notifyListeners();
      return data;
    } on ApiException catch (e) {
      _error = e.message; notifyListeners();
      return null;
    }
  }

  Future<void> cargarBandeja() async {
    try {
      final data = await ApiClient.get('/api/v1/matching/bandeja/', query: {'modo': _modo});
      _likes = List<Map<String, dynamic>>.from(data['likes']);
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> responderLike(int likeId, String respuesta) async {
    try {
      final data = await ApiClient.post('/api/v1/matching/responder/$likeId/', body: {'respuesta': respuesta});
      _likes.removeWhere((l) => l['like_id'] == likeId);
      notifyListeners();
      return data;
    } on ApiException catch (e) {
      _error = e.message; notifyListeners();
      return null;
    }
  }

  Future<void> cargarMatches() async {
    try {
      final data = await ApiClient.get('/api/v1/matching/matches/', query: {'modo': _modo});
      _matches = (data as List).map((m) => MatchModel.fromJson(m)).toList();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() { _error = null; notifyListeners(); }
}
