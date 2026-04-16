import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_chat.dart';
import 'provider_matching.dart';
import 'api_client.dart';
import 'screen_chat_detail.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().cargarConversaciones();
      context.read<MatchingProvider>().cargarMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chat    = context.watch<ChatProvider>();
    final matches = context.watch<MatchingProvider>().matches;

    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              const Text('Chats',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900,
                  color: KoraColors.textPrimary, letterSpacing: -0.5,
                )),
              const Spacer(),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: KoraColors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KoraColors.divider),
                ),
                child: const Icon(Icons.search_rounded, color: KoraColors.textSecondary, size: 20),
              ),
            ]),
          ),
          // Nuevos matches row
          if (matches.isNotEmpty) _MatchesRow(matches: matches),
          // Lista
          Expanded(
            child: chat.loading
              ? const Center(child: CircularProgressIndicator(color: KoraColors.primary, strokeWidth: 2))
              : chat.conversaciones.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: KoraColors.bgElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: KoraColors.divider),
                        ),
                        child: const Text('💬', style: TextStyle(fontSize: 44)),
                      ),
                      const SizedBox(height: 24),
                      const Text('Sin chats todavía',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                            color: KoraColors.textPrimary, letterSpacing: -0.3)),
                      const SizedBox(height: 8),
                      const Text('¡Haz match para chatear!',
                        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
                    ]))
                : RefreshIndicator(
                    onRefresh: () => chat.cargarConversaciones(),
                    color: KoraColors.primary,
                    backgroundColor: KoraColors.bgCard,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: chat.conversaciones.length,
                      itemBuilder: (ctx, i) {
                        final conv = chat.conversaciones[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              roomId:    conv.roomId,
                              nombre:    conv.otroUsuarioNombre,
                              fotoUrl:   conv.otroFotoUrl,
                              usuarioId: conv.otroUsuarioId,
                            ),
                          )),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: KoraColors.bgCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: KoraColors.divider),
                            ),
                            child: Row(children: [
                              // Avatar
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: KoraColors.primary.withOpacity(0.12),
                                backgroundImage: conv.otroFotoUrl != null
                                    ? NetworkImage('${ApiClient.baseUrl}${conv.otroFotoUrl}')
                                    : null,
                                child: conv.otroFotoUrl == null
                                    ? Text(conv.otroUsuarioNombre.isNotEmpty
                                          ? conv.otroUsuarioNombre[0].toUpperCase()
                                          : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: KoraColors.primary))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(conv.otroUsuarioNombre,
                                    style: const TextStyle(fontWeight: FontWeight.w700,
                                        color: KoraColors.textPrimary, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  conv.ultimoMensaje != null
                                    ? Text(conv.ultimoMensaje!.contenido,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13))
                                    : const Text('Nuevo match 🎉',
                                        style: TextStyle(color: KoraColors.primary,
                                            fontStyle: FontStyle.italic, fontSize: 13)),
                                ],
                              )),
                              // Tiempo
                              if (conv.ultimoMensaje != null)
                                Text(_timeago(conv.ultimoMensaje!.createdAt),
                                  style: const TextStyle(color: KoraColors.textHint, fontSize: 12)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  String _timeago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─── Fila de nuevos matches ───────────────────────────────────────
class _MatchesRow extends StatelessWidget {
  final List<MatchModel> matches;
  const _MatchesRow({required this.matches});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text('Nuevos matches',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: KoraColors.textSecondary, letterSpacing: 0.3)),
      ),
      SizedBox(
        height: 92,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: matches.length,
          itemBuilder: (_, i) {
            final m    = matches[i];
            final otro = m.otroUsuario;
            final nombre = otro?['nombre'] as String? ?? '';
            final fotoUrl = otro?['foto_url'] as String?;
            final modeColor = m.modo == 'pareja'
                ? KoraColors.match
                : m.modo == 'amistad'
                    ? KoraColors.primary
                    : const Color(0xFF0A84FF);

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: modeColor, width: 2),
                    color: KoraColors.bgElevated,
                    boxShadow: [
                      BoxShadow(color: modeColor.withOpacity(0.3),
                          blurRadius: 10, spreadRadius: 1),
                    ],
                  ),
                  child: ClipOval(
                    child: fotoUrl != null
                        ? Image.network('${ApiClient.baseUrl}$fotoUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _letter(nombre, modeColor))
                        : _letter(nombre, modeColor),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(nombre,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KoraColors.textSecondary,
                        fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ]),
            );
          },
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Divider(color: KoraColors.divider, height: 20),
      ),
    ]);
  }

  Widget _letter(String name, Color color) {
    return Container(
      color: color.withOpacity(0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
