import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'services/auth_service.dart';

// Helper para parseo seguro de int que la API puede devolver como String
int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class MensajeModel {
  final int? id;
  final String contenido;
  final int remitenteId;
  final String remitenteNombre;
  final DateTime createdAt;
  final bool leido;
  final String tipo; // 'mensaje' | 'sistema' | 'ia'

  MensajeModel({
    this.id, required this.contenido,
    required this.remitenteId, required this.remitenteNombre,
    required this.createdAt, this.leido = false,
    this.tipo = 'mensaje',
  });

  factory MensajeModel.fromApi(Map<String, dynamic> j) => MensajeModel(
    id:              j['id'],
    contenido:       j['contenido'] ?? '',
    remitenteId:     _toInt(j['remitente']?['id']),
    remitenteNombre: j['remitente']?['nombre'] ?? '',
    createdAt:       DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    leido:           j['leido'] ?? false,
    tipo:            j['tipo'] ?? 'mensaje',
  );

  factory MensajeModel.fromWs(Map<String, dynamic> j) => MensajeModel(
    id:              j['id'],
    contenido:       j['contenido'] ?? '',
    remitenteId:     _toInt(j['remitente']?['id']),
    remitenteNombre: j['remitente']?['nombre'] ?? '',
    createdAt:       DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    tipo:            j['tipo'] ?? 'mensaje',
  );
}

class ConversacionInfo {
  final String roomId;
  final int otroUsuarioId;
  final String otroUsuarioNombre;
  final String? otroFotoUrl;
  final MensajeModel? ultimoMensaje;

  ConversacionInfo({
    required this.roomId, required this.otroUsuarioId,
    required this.otroUsuarioNombre, this.otroFotoUrl, this.ultimoMensaje,
  });
}

class ChatProvider with ChangeNotifier {
  final Map<String, List<MensajeModel>> _mensajes      = {};
  final Map<String, ConversacionInfo>   _conversaciones = {};

  WebSocketChannel? _chatWs;
  WebSocketChannel? _notifWs;
  StreamSubscription? _chatSub;
  StreamSubscription? _notifSub;
  String? _activeRoom;
  bool _typing    = false;
  bool _loading   = false;
  bool _disposed  = false;
  int  _reconectos = 0;
  Timer? _reconTimer;

  List<ConversacionInfo> get conversaciones => _conversaciones.values.toList()
    ..sort((a, b) {
      final ta = a.ultimoMensaje?.createdAt ?? DateTime(2000);
      final tb = b.ultimoMensaje?.createdAt ?? DateTime(2000);
      return tb.compareTo(ta);
    });

  List<MensajeModel> getMensajes(String roomId) => _mensajes[roomId] ?? [];
  bool get loading  => _loading;
  bool get typing   => _typing;

  // ── Cargar conversaciones ────────────────────────────────────────
  Future<void> cargarConversaciones() async {
    try {
      final data = await ApiClient.get('/api/v1/chat/conversaciones/');
      for (final c in (data as List)) {
        final otro = c['otro_usuario'] as Map<String, dynamic>;
        final last = c['ultimo_mensaje'];
        _conversaciones[c['room_id']] = ConversacionInfo(
          roomId:             c['room_id'],
          otroUsuarioId:      otro['id'],
          otroUsuarioNombre:  otro['nombre'] ?? '',
          otroFotoUrl:        otro['foto_url'],
          ultimoMensaje:      last != null ? MensajeModel.fromApi(last) : null,
        );
      }
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  // ── Iniciar / obtener conversación ───────────────────────────────
  Future<String?> obtenerOCrearConversacion(int otroUserId) async {
    try {
      final data = await ApiClient.post('/api/v1/chat/conversaciones/', body: {'usuario_id': otroUserId});
      final roomId = data['room_id'] as String;
      final otro   = data['otro_usuario'] as Map<String, dynamic>;
      _conversaciones[roomId] = ConversacionInfo(
        roomId: roomId,
        otroUsuarioId:     otro['id'],
        otroUsuarioNombre: otro['nombre'] ?? '',
        otroFotoUrl:       otro['foto_url'],
      );
      if (!_disposed) notifyListeners();
      return roomId;
    } on ApiException { return null; }
  }

  // ── Historial ────────────────────────────────────────────────────
  Future<void> cargarHistorial(String roomId) async {
    _loading = true; if (!_disposed) notifyListeners();
    try {
      final data = await ApiClient.get('/api/v1/chat/conversaciones/$roomId/mensajes/');
      _mensajes[roomId] = (data as List).map((m) => MensajeModel.fromApi(m)).toList();
    } catch (_) {}
    _loading = false; if (!_disposed) notifyListeners();
  }

  // ── WebSocket Chat ───────────────────────────────────────────────
  Future<void> conectarChat(String roomId) async {
    if (_activeRoom == roomId && _chatWs != null) return;
    await _cerrarChatWs();
    _activeRoom = roomId;
    _reconectos = 0;
    await _abrirChatWs(roomId);
  }

  Future<void> _abrirChatWs(String roomId) async {
    if (_disposed) return;
    final token = await AuthService.getAccessToken();
    if (token == null) return;
    final base = kIsWeb ? dotenv.env['WS_URL_WEB']! : dotenv.env['WS_URL']!;
    try {
      _chatWs  = WebSocketChannel.connect(Uri.parse('$base/ws/chat/$roomId/?token=$token'));
      _chatSub = _chatWs!.stream.listen(_onChatMsg,
        onError: (_) => _reconectarChat(roomId),
        onDone:  () => _reconectarChat(roomId),
        cancelOnError: false,
      );
    } catch (_) { _reconectarChat(roomId); }
  }

  void _onChatMsg(dynamic raw) {
    if (_disposed) return;
    try {
      final d = jsonDecode(raw as String) as Map<String, dynamic>;
      if (d['tipo'] == 'mensaje') {
        final msg = MensajeModel.fromWs(d);
        _mensajes.putIfAbsent(_activeRoom!, () => []);
        if (!_mensajes[_activeRoom!]!.any((m) => m.id == msg.id)) {
          _mensajes[_activeRoom!]!.add(msg);
        }
        _typing = false;
        if (!_disposed) notifyListeners();
      } else if (d['tipo'] == 'typing') {
        _typing = true; if (!_disposed) notifyListeners();
        Future.delayed(const Duration(seconds: 3), () {
          if (!_disposed) { _typing = false; notifyListeners(); }
        });
      }
    } catch (_) {}
  }

  void _reconectarChat(String roomId) {
    if (_disposed || _activeRoom != roomId || _reconectos >= 5) return;
    _reconectos++;
    _reconTimer?.cancel();
    _reconTimer = Timer(Duration(seconds: _reconectos * 2), () async {
      if (!_disposed && _activeRoom == roomId) {
        await _cerrarChatWs(resetActive: false);
        await _abrirChatWs(roomId);
      }
    });
  }

  Future<void> _cerrarChatWs({bool resetActive = true}) async {
    _reconTimer?.cancel();
    await _chatSub?.cancel(); _chatSub = null;
    try { await _chatWs?.sink.close(); } catch (_) {}
    _chatWs = null;
    if (resetActive) _activeRoom = null;
  }

  Future<void> desconectarChat() async {
    _reconectos = 99;
    await _cerrarChatWs();
  }

  // ── WebSocket Notificaciones ─────────────────────────────────────
  Future<void> conectarNotificaciones() async {
    if (_notifWs != null) return;
    final token = await AuthService.getAccessToken();
    if (token == null) return;
    final base = kIsWeb ? dotenv.env['WS_URL_WEB']! : dotenv.env['WS_URL']!;
    try {
      _notifWs  = WebSocketChannel.connect(Uri.parse('$base/ws/notifications/?token=$token'));
      _notifSub = _notifWs!.stream.listen(_onNotifMsg,
        onError: (_) {}, onDone: () {}, cancelOnError: false,
      );
    } catch (_) {}
  }

  void _onNotifMsg(dynamic raw) {
    // Las notificaciones se procesan globalmente
    // En producción conectar con flutter_local_notifications
    if (_disposed) return;
    try {
      final d = jsonDecode(raw as String) as Map<String, dynamic>;
      if (d['tipo'] == 'notificacion') {
        // TODO: mostrar notificación local
      }
    } catch (_) {}
  }

  // ── Enviar ───────────────────────────────────────────────────────
  void enviarMensaje(String texto) {
    if (_chatWs == null || texto.trim().isEmpty) return;
    _chatWs!.sink.add(jsonEncode({'tipo': 'mensaje', 'contenido': texto.trim()}));
  }

  void enviarTyping() {
    try { _chatWs?.sink.add(jsonEncode({'tipo': 'typing'})); } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _reconectos = 99;
    _reconTimer?.cancel();
    _chatSub?.cancel();
    _notifSub?.cancel();
    try { _chatWs?.sink.close(); } catch (_) {}
    try { _notifWs?.sink.close(); } catch (_) {}
    super.dispose();
  }
}
