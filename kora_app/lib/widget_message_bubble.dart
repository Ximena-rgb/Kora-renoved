import 'package:flutter/material.dart';
// Widget stub — burbujas de chat implementadas en screen_chat_detail.dart
class MessageBubble extends StatelessWidget {
  final String content;
  final bool isMine;
  const MessageBubble({super.key, required this.content, required this.isMine});
  @override
  Widget build(BuildContext context) => Align(
    alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF6C63FF) : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(content, style: TextStyle(color: isMine ? Colors.white : Colors.black87)),
    ),
  );
}
