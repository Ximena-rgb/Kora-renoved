import 'package:flutter/material.dart';
import 'api_client.dart';

class DesparcheProvider with ChangeNotifier {
  final String roomId;
  DesparcheProvider({required this.roomId});

  Map<String, dynamic>? _sesion;
  bool _loading = false;
  String? _error;
  bool _sesionIniciada = false;
  bool _soyCreador     = false;

  Map<String, dynamic>? get sesion     => _sesion;
  bool get loading                     => _loading;
  String? get error                    => _error;
  bool get sesionIniciada              => _sesionIniciada;
  bool get soyCreador                  => _soyCreador;

  Future<void> crearSesion(String tipoJuego) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await ApiClient.post('/api/v1/desparche/sesiones/crear/', body: {
        'tipo_juego': tipoJuego,
        'room_id':    roomId,
        'max_rondas': 10,
      });
      _sesion       = data;
      _soyCreador   = true;
      _sesionIniciada = false;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _loading = false; notifyListeners();
  }

  Future<void> unirse(int sesionId) async {
    _loading = true; notifyListeners();
    try {
      final data = await ApiClient.post('/api/v1/desparche/sesiones/$sesionId/unirse/');
      _sesion = data;
    } on ApiException catch (e) { _error = e.message; }
    _loading = false; notifyListeners();
  }

  Future<void> iniciarSesion() async {
    if (_sesion == null) return;
    _loading = true; notifyListeners();
    try {
      final data = await ApiClient.post('/api/v1/desparche/sesiones/${_sesion!["id"]}/iniciar/');
      _sesion         = data;
      _sesionIniciada = true;
    } on ApiException catch (e) { _error = e.message; }
    _loading = false; notifyListeners();
  }

  Future<void> siguienteRonda() async {
    if (_sesion == null) return;
    _loading = true; notifyListeners();
    try {
      final data = await ApiClient.post('/api/v1/desparche/sesiones/${_sesion!["id"]}/siguiente/');
      _sesion = data;
    } on ApiException catch (e) { _error = e.message; }
    _loading = false; notifyListeners();
  }

  Future<void> votar(int rondaId, int votadoId) async {
    try {
      await ApiClient.post('/api/v1/desparche/rondas/$rondaId/votar/', body: {
        'votado_id': votadoId,
      });
      await _refreshSesion();
    } on ApiException catch (e) { _error = e.message; notifyListeners(); }
  }

  Future<void> _refreshSesion() async {
    if (_sesion == null) return;
    try {
      final data = await ApiClient.get('/api/v1/desparche/sesiones/${_sesion!["id"]}/');
      _sesion = data; notifyListeners();
    } catch (_) {}
  }

  void verResultados(BuildContext context) {
    // navegar a pantalla de resultados (implementar si se necesita)
    notifyListeners();
  }
}
