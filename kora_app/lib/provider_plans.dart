import 'package:flutter/material.dart';
import 'api_client.dart';

class PlansProvider with ChangeNotifier {
  List<Map<String, dynamic>> _planes    = [];
  List<Map<String, dynamic>> _misPlanes = [];
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> get planes    => _planes;
  List<Map<String, dynamic>> get misPlanes => _misPlanes;
  bool get loading    => _loading;
  String? get error   => _error;

  Future<void> cargarPlanes({String? tipo, String? zona}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final q = <String, String>{};
      if (tipo != null && tipo.isNotEmpty) q['tipo'] = tipo;
      if (zona != null && zona.isNotEmpty) q['zona'] = zona;
      final data = await ApiClient.get('/api/v1/plans/', query: q);
      _planes = List<Map<String, dynamic>>.from(data as List);
    } on ApiException catch (e) { _error = e.message; }
    _loading = false; notifyListeners();
  }

  Future<void> cargarMisPlanes() async {
    try {
      final data = await ApiClient.get('/api/v1/plans/mis-planes/');
      final creados   = List<Map<String, dynamic>>.from(data['creados'] ?? []);
      final asistiendo = List<Map<String, dynamic>>.from(data['asistiendo'] ?? []);
      _misPlanes = [...creados, ...asistiendo];
      notifyListeners();
    } catch (_) {}
  }

  void clearError() { _error = null; notifyListeners(); }
}
