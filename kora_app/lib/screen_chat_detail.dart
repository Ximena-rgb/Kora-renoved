import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'provider_chat.dart';
import 'api_client.dart';
import 'screen_desparche.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final String nombre;
  final String? fotoUrl;
  final int usuarioId;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.nombre,
    this.fotoUrl,
    required this.usuarioId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = context.read<ChatProvider>();
      await chat.cargarHistorial(widget.roomId);
      await chat.conectarChat(widget.roomId);
      _scrollToBottom(jump: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    context.read<ChatProvider>().desconectarChat();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(max);
      } else {
        _scroll.animateTo(max,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = int.tryParse(context.read<AuthProvider>().user?.id ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: KoraColors.bg,
      appBar: AppBar(
        backgroundColor: KoraColors.bgCard,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: KoraColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: KoraColors.primary.withOpacity(0.15),
            backgroundImage: widget.fotoUrl != null
                ? NetworkImage('${ApiClient.baseUrl}${widget.fotoUrl}')
                : null,
            child: widget.fotoUrl == null
                ? Text(widget.nombre.isNotEmpty ? widget.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(color: KoraColors.primary, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.nombre,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: KoraColors.textPrimary)),
            Consumer<ChatProvider>(
              builder: (_, chat, __) => Text(
                chat.typing ? 'escribiendo...' : 'en línea',
                style: TextStyle(fontSize: 11,
                  color: chat.typing ? KoraColors.primary : KoraColors.textHint),
              ),
            ),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Text('🎮', style: TextStyle(fontSize: 20)),
            tooltip: 'Modo Desparche',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DesparcheScreen(roomId: widget.roomId)),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: KoraColors.divider),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (_, chat, __) {
              final msgs = chat.getMensajes(widget.roomId);
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              if (chat.loading) {
                return const Center(child: CircularProgressIndicator(
                    color: KoraColors.primary, strokeWidth: 2));
              }
              if (msgs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: KoraColors.bgElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: KoraColors.divider),
                      ),
                      child: const Text('💌', style: TextStyle(fontSize: 44)),
                    ),
                    const SizedBox(height: 18),
                    Text('¡Saluda a ${widget.nombre}! 👋',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                            color: KoraColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Sé el primero en escribir',
                        style: TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
                  ]),
                );
              }

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: msgs.length + (chat.typing ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == msgs.length && chat.typing) {
                    return const _TypingIndicator();
                  }
                  final msg    = msgs[i];
                  final isMine = msg.remitenteId == myId;
                  final isIA   = msg.tipo != 'mensaje';
                  return _Burbuja(msg: msg, isMine: isMine, isIA: isIA);
                },
              );
            },
          ),
        ),
        _InputBar(ctrl: _ctrl, onSend: _enviar,
            onTyping: () => context.read<ChatProvider>().enviarTyping()),
      ]),
    );
  }

  void _enviar() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    context.read<ChatProvider>().enviarMensaje(txt);
    _ctrl.clear();
    _scrollToBottom();
  }
}

// ── Burbuja ────────────────────────────────────────────────────────
class _Burbuja extends StatelessWidget {
  final MensajeModel msg;
  final bool isMine;
  final bool isIA;
  const _Burbuja({required this.msg, required this.isMine, this.isIA = false});

  @override
  Widget build(BuildContext context) {
    if (isIA) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: KoraColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KoraColors.primary.withOpacity(0.2)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('💜 ', style: TextStyle(fontSize: 12)),
              Text('Asistente Kora',
                  style: TextStyle(fontSize: 11, color: KoraColors.primary.withOpacity(0.9),
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text(msg.contenido,
                textAlign: TextAlign.center,
                style: const TextStyle(color: KoraColors.textPrimary, fontSize: 14,
                    fontStyle: FontStyle.italic, height: 1.5)),
          ]),
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          gradient: isMine ? KoraGradients.mainGradient : null,
          color: isMine ? null : KoraColors.bgElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: KoraColors.divider),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(msg.contenido,
                style: TextStyle(
                    color: isMine ? Colors.white : KoraColors.textPrimary,
                    fontSize: 15, height: 1.4)),
            const SizedBox(height: 3),
            Text(_hora(msg.createdAt),
                style: TextStyle(
                    color: isMine ? Colors.white54 : KoraColors.textHint,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _hora(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: KoraColors.bgElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KoraColors.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(width: 7, height: 7,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: KoraColors.textHint)),
            ),
        ]),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final VoidCallback onTyping;
  const _InputBar({required this.ctrl, required this.onSend, required this.onTyping});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 14, right: 10, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: KoraColors.bgCard,
        border: Border(top: BorderSide(color: KoraColors.divider)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            onChanged: (_) => onTyping(),
            maxLines: 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: KoraColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Escribe un mensaje...',
              hintStyle: const TextStyle(color: KoraColors.textHint),
              filled: true,
              fillColor: KoraColors.bgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: KoraGradients.mainGradient,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
