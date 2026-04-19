import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'provider_matching.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarScore();
      // Cargar intenciones para mostrarlas en el perfil
      context.read<MatchingProvider>().cargarIntenciones();
    });
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
                _buildIntencionesCard(context),
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
          const Text('⭐ Reputación',
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

  Widget _buildIntencionesCard(BuildContext context) {
    final mp = context.watch<MatchingProvider>();
    final intenciones = mp.intenciones;

    const _info = {
      'pareja':  ('❤️', 'Pareja',  Color(0xFFFF2D55)),
      'amistad': ('🤝', 'Amistad', Color(0xFFE040FB)),
      'estudio': ('📚', 'Estudio', Color(0xFF0A84FF)),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KoraColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Busco en Kora',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: KoraColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _editarPerfil(context),
            child: Text('Editar',
              style: TextStyle(fontSize: 13, color: KoraColors.primary,
                  fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        if (intenciones.isEmpty)
          Text('No has configurado tus intenciones aún.',
            style: TextStyle(fontSize: 13, color: KoraColors.textHint))
        else
          Wrap(spacing: 8, runSpacing: 8, children: intenciones.map((key) {
            final info = _info[key];
            if (info == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: info.$3.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: info.$3.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(info.$1, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(info.$2,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: info.$3)),
              ]),
            );
          }).toList()),
      ]),
    );
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
    final user     = context.read<AuthProvider>().user;
    final bioCtrl  = TextEditingController(text: user?.bio ?? '');
    final intereses = List<String>.from(user?.intereses ?? []);
    final mp = context.read<MatchingProvider>();
    final intenciones = Set<String>.from(mp.intenciones);
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: KoraColors.divider,
                  borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              const Text('Editar perfil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: KoraColors.textPrimary)),
              const SizedBox(height: 20),

              // ── Bio ─────────────────────────────────────────────
              Text('Sobre mí',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: KoraColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(color: KoraColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Escribe algo sobre ti...',
                  hintStyle: TextStyle(color: KoraColors.textHint),
                  filled: true,
                  fillColor: KoraColors.bgElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: KoraColors.primary, width: 1.5)),
                  counterStyle: TextStyle(color: KoraColors.textHint, fontSize: 11),
                ),
              ),
              const SizedBox(height: 20),

              // ── Intereses ────────────────────────────────────────
              Text('Intereses / Hobbies',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: KoraColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ...intereses.map((g) => Chip(
                  label: Text(g,
                    style: const TextStyle(fontSize: 12, color: KoraColors.textPrimary)),
                  deleteIcon: const Icon(Icons.close, size: 14,
                      color: KoraColors.textSecondary),
                  onDeleted: () => setS(() => intereses.remove(g)),
                  backgroundColor: KoraColors.primary.withOpacity(0.10),
                  side: BorderSide(color: KoraColors.primary.withOpacity(0.25)),
                )),
                if (intereses.length < 15)
                  ActionChip(
                    label: const Text('+ Agregar',
                      style: TextStyle(fontSize: 12, color: KoraColors.primary,
                          fontWeight: FontWeight.w600)),
                    backgroundColor: KoraColors.bgElevated,
                    side: BorderSide(color: KoraColors.primary.withOpacity(0.3)),
                    onPressed: () async {
                      final t = await showDialog<String>(
                        context: ctx,
                        builder: (_) => _InputDialog(
                            hint: 'Ej: senderismo, fotografía...'),
                      );
                      if (t != null && t.trim().isNotEmpty) {
                        setS(() => intereses.add(t.trim()));
                      }
                    },
                  ),
              ]),
              const SizedBox(height: 20),

              // ── Intenciones ──────────────────────────────────────
              Text('Busco en Kora',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: KoraColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Selecciona al menos una opción.',
                style: TextStyle(fontSize: 11, color: KoraColors.textHint)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                _IntencionChip(
                  label: '❤️ Pareja',
                  selected: intenciones.contains('pareja'),
                  onTap: () => setS(() => intenciones.contains('pareja')
                      ? intenciones.remove('pareja')
                      : intenciones.add('pareja')),
                ),
                _IntencionChip(
                  label: '🤝 Amistad',
                  selected: intenciones.contains('amistad'),
                  onTap: () => setS(() => intenciones.contains('amistad')
                      ? intenciones.remove('amistad')
                      : intenciones.add('amistad')),
                ),
                _IntencionChip(
                  label: '📚 Estudio',
                  selected: intenciones.contains('estudio'),
                  onTap: () => setS(() => intenciones.contains('estudio')
                      ? intenciones.remove('estudio')
                      : intenciones.add('estudio')),
                ),
              ]),
              if (intenciones.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Elige al menos una.',
                    style: TextStyle(fontSize: 11, color: KoraColors.accent)),
                ),

              const SizedBox(height: 28),

              // ── Guardar ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: (guardando || intenciones.isEmpty)
                        ? null : KoraGradients.mainGradient,
                    color: (guardando || intenciones.isEmpty)
                        ? KoraColors.bgElevated : null,
                  ),
                  child: ElevatedButton(
                    onPressed: (guardando || intenciones.isEmpty) ? null : () async {
                      setS(() => guardando = true);
                      try {
                        await ApiClient.patch('/api/v1/users/me/profile/', body: {
                          'bio':       bioCtrl.text.trim(),
                          'intereses': intereses,
                        });
                        await ApiClient.patch('/api/v1/onboarding/intenciones/', body: {
                          'intenciones': intenciones.toList(),
                        });
                        if (ctx.mounted) {
                          await ctx.read<MatchingProvider>().cargarIntenciones();
                          Navigator.pop(ctx);
                        }
                      } catch (_) {
                        setS(() => guardando = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: guardando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar cambios',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ),
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

// ── Chip de intención editable ────────────────────────────────────
class _IntencionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IntencionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? KoraColors.primary.withOpacity(0.15)
              : KoraColors.bgElevated,
          border: Border.all(
            color: selected
                ? KoraColors.primary.withOpacity(0.6)
                : KoraColors.divider,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? KoraColors.primary : KoraColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Diálogo de texto simple para agregar interés ──────────────────
class _InputDialog extends StatefulWidget {
  final String hint;
  const _InputDialog({required this.hint});

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KoraColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Agregar interés',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: KoraColors.textPrimary)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: KoraColors.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: KoraColors.textHint),
          filled: true,
          fillColor: KoraColors.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(color: KoraColors.textSecondary))),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: KoraColors.primary),
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Agregar',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700))),
      ],
    );
  }
}
