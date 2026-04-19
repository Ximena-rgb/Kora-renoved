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
  String _modo      = '';    // vacío hasta saber las intenciones reales del usuario
  bool _loading     = false;
  String? _error;
  Map<String, dynamic>? _likesInfo;
  List<String> _intenciones = [];
  bool _intencionesListas   = false; // false = todavía no se han cargado del backend

  List<CandidatoModel> get deck     => _deck;
  List<Map<String, dynamic>> get likes => _likes;
  List<MatchModel> get matches      => _matches;
  String get modo                   => _modo;
  bool get loading                  => _loading;
  String? get error                 => _error;
  Map<String, dynamic>? get likesInfo => _likesInfo;
  List<String> get intenciones      => _intenciones;
  bool get intencionesListas        => _intencionesListas;

  /// Modos disponibles según intenciones.
  /// Retorna lista vacía hasta que las intenciones hayan cargado del backend.
  /// NUNCA muestra modos que el usuario no eligió — sin fallback a todos.
  List<String> get modosDisponibles {
    if (!_intencionesListas) return []; // aún cargando
    if (_intenciones.isEmpty) return []; // cargó pero vacío → error de red o usuario sin intenciones
    return ['pareja', 'amistad', 'estudio']
        .where((m) => _intenciones.contains(m))
        .toList();
  }

  /// Carga las intenciones del usuario desde el backend
  Future<void> cargarIntenciones() async {
    try {
      final data = await ApiClient.get('/api/v1/onboarding/estado/');
      final lista = data['intenciones'];
      if (lista is List && lista.isNotEmpty) {
        _intenciones = List<String>.from(lista);
        // Siempre sincronizar el modo activo con las intenciones reales.
        // Si el modo actual no está en la lista → usar el primero.
        // Si el modo está vacío (primera carga) → usar el primero.
        if (_modo.isEmpty || !_intenciones.contains(_modo)) {
          _modo = _intenciones.first;
        }
      } else {
        // El API respondió pero sin intenciones → dejar vacío, no fallback
        _intenciones = [];
        _modo = '';
      }
    } catch (_) {
      // Error de red → dejar vacío, la UI mostrará estado de error
      _intenciones = [];
      _modo = '';
    } finally {
      _intencionesListas = true;
      notifyListeners();
    }
  }

  void setModo(String m) {
    // Solo permitir modos que el usuario tiene en sus intenciones
    if (_intencionesListas && _intenciones.isNotEmpty && !_intenciones.contains(m)) return;
    _modo = m;
    cargarDeck();
  }

  Future<void> cargarDeck() async {
    // No pedir deck si no hay modo válido todavía
    if (_modo.isEmpty) return;
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
