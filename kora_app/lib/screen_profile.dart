import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'api_client.dart';
import 'screen_mfa.dart';
import 'widgets_kora_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  Map<String, dynamic>? _score;
  bool _loadingScore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarScore());
  }

  Future<void> _cargarScore() async {
    setState(() => _loadingScore = true);
    try {
      final data = await ApiClient.get('/api/v1/reputation/mi-score/');
      if (mounted) setState(() { _score = data; _loadingScore = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingScore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: RefreshIndicator(
        onRefresh: _cargarScore,
        color: KoraColors.primary,
        backgroundColor: KoraColors.bgCard,
        child: CustomScrollView(slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: KoraColors.bgCard,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: KoraColors.textSecondary, size: 22),
                onPressed: () => _showMenu(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Glow de fondo
                  Positioned(
                    top: -40, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        width: 200, height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [KoraColors.primary.withOpacity(0.2), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        // Avatar
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: KoraGradients.mainGradient,
                            boxShadow: [
                              BoxShadow(color: KoraColors.primary.withOpacity(0.4),
                                  blurRadius: 20, spreadRadius: 2),
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: KoraColors.bgElevated,
                            backgroundImage: user.foto_url != null && user.foto_url!.isNotEmpty
                                ? NetworkImage('${ApiClient.baseUrl}${user.foto_url}')
                                : null,
                            child: user.foto_url == null || user.foto_url!.isEmpty
                                ? Text(user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 36, color: Colors.white,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user.nombre,
                            style: const TextStyle(color: KoraColors.textPrimary, fontSize: 22,
                                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text('${user.carrera} · Sem ${user.semestre}',
                          style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: KoraColors.divider),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _buildScoreCard(),
                const SizedBox(height: 14),
                _buildInsignias(),
                const SizedBox(height: 14),
                _buildAcciones(context),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildScoreCard() {
    if (_loadingScore) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: KoraColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KoraColors.divider),
        ),
        child: const Center(child: CircularProgressIndicator(
            color: KoraColors.primary, strokeWidth: 2)),
      );
    }

    final total   = (_score?['score_total'] ?? 50.0) as num;
    final calif   = (_score?['score_calificacion'] ?? 50.0) as num;
    final puntual = (_score?['score_puntualidad'] ?? 50.0) as num;
    final asist   = (_score?['score_asistencia'] ?? 50.0) as num;
    final asistidos = _score?['planes_asistidos'] ?? 0;
    final puntuales = _score?['checkins_puntuales'] ?? 0;
    final promedio  = _score?['calificacion_promedio'];
    final color     = scoreColor(total.toDouble());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KoraColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('⭐ Score de Confianza',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: KoraColors.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text('${total.toStringAsFixed(0)}/100',
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total / 100,
            minHeight: 8,
            backgroundColor: KoraColors.bgElevated,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 20),
        _scoreFila('📅 Asistencia', asist.toDouble(), '$asistidos planes'),
        const SizedBox(height: 10),
        _scoreFila('⏰ Puntualidad', puntual.toDouble(), '$puntuales puntuales'),
        const SizedBox(height: 10),
        _scoreFila('👥 Calificación', calif.toDouble(),
            promedio != null ? '${(promedio as num).toStringAsFixed(1)}★' : 'Sin datos'),
      ]),
    );
  }

  Widget _scoreFila(String label, double val, String detalle) {
    final c = scoreColor(val);
    return Row(children: [
      SizedBox(width: 130,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: KoraColors.textSecondary))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: val / 100,
            minHeight: 5,
            backgroundColor: KoraColors.bgElevated,
            valueColor: AlwaysStoppedAnimation(c),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(detalle, style: const TextStyle(fontSize: 11, color: KoraColors.textSecondary)),
    ]);
  }

  Widget _buildInsignias() {
    final insignias = (_score?['insignias'] as List?) ?? [];
    if (insignias.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KoraColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mis Insignias',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: KoraColors.textPrimary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: insignias.map((ins) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: KoraColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KoraColors.primary.withOpacity(0.25)),
              ),
              child: Text(ins['nombre'] ?? ins['codigo'] ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: KoraColors.primary)),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _buildAcciones(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KoraColors.divider),
      ),
      child: Column(children: [
        _tile(Icons.edit_outlined, 'Editar perfil', () => _editarPerfil(context)),
        Divider(height: 1, color: KoraColors.divider),
        _tile(Icons.security_outlined, 'Seguridad y MFA',
          () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MfaSetupScreen()))),
        Divider(height: 1, color: KoraColors.divider),
        _tile(Icons.notifications_outlined, 'Notificaciones',
          () => _notificaciones(context)),
        Divider(height: 1, color: KoraColors.divider),
        _tile(Icons.logout_rounded, 'Cerrar sesión', () => _logout(context),
            color: KoraColors.pass),
      ]),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? KoraColors.primary;
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: c, size: 18),
      ),
      title: Text(label,
          style: TextStyle(color: color ?? KoraColors.textPrimary,
              fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: color == null
          ? const Icon(Icons.chevron_right, color: KoraColors.textHint, size: 18)
          : null,
      onTap: onTap,
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: KoraColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: KoraColors.pass),
            title: const Text('Cerrar sesión', style: TextStyle(color: KoraColors.pass)),
            onTap: () { Navigator.pop(context); _logout(context); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _editarPerfil(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final bioCtrl = TextEditingController(text: user?.bio ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KoraColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: KoraColors.divider,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Editar perfil',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: KoraColors.textPrimary))),
          const SizedBox(height: 16),
          KoraInputField(
            controller: bioCtrl,
            hint: 'Escribe algo sobre ti...',
            icon: Icons.edit_note_outlined),
          const SizedBox(height: 20),
          KoraGradientActionBtn(
            label: 'Guardar',
            loading: false,
            onPressed: () async {
              try {
                await ApiClient.patch('/api/v1/users/me/profile/',
                    body: {'bio_corta': bioCtrl.text});
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {}
            },
          ),
        ]),
      ),
    );
  }

  void _notificaciones(BuildContext context) {
    bool pushActivo = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: KoraColors.divider,
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft,
              child: Text('Notificaciones',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: KoraColors.textPrimary))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: KoraColors.bgElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KoraColors.divider)),
              child: Row(children: [
                const Expanded(child: Text('Notificaciones push',
                  style: TextStyle(color: KoraColors.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 14))),
                Switch(
                  value: pushActivo,
                  onChanged: (v) => setS(() => pushActivo = v),
                  activeColor: KoraColors.primary),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
  }
}
