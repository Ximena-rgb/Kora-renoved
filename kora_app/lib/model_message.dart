// Model stub — mensajes ahora se manejan como MensajeModel en ChatProvider
class MessageModel {
  final int? id;
  final String content;
  final String senderId;
  final DateTime timestamp;
  final bool isRead;
  MessageModel({this.id, required this.content, required this.senderId,
      required this.timestamp, this.isRead = false});
  factory MessageModel.fromApi(Map<String, dynamic> j) => MessageModel(
    id: j['id'], content: j['contenido'] ?? '',
    senderId: j['remitente']?['id']?.toString() ?? '',
    timestamp: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    isRead: j['leido'] ?? false,
  );
  factory MessageModel.fromWs(Map<String, dynamic> j) => MessageModel(
    id: j['id'], content: j['contenido'] ?? '',
    senderId: j['remitente']?['id']?.toString() ?? '',
    timestamp: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
  );
}
