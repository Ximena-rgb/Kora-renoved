import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_matching.dart';
import 'api_client.dart';
import 'screen_user_detail.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  int _subTab = 0;

  // Filtros
  RangeValues _edadRange = const RangeValues(18, 30);
  double _distanciaMax = 10;
  Set<String> _carreras = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mp = context.read<MatchingProvider>();
      await mp.cargarIntenciones();
      // Solo pedir el deck si hay un modo válido (intenciones cargadas correctamente)
      if (mp.modo.isNotEmpty) {
        mp.cargarDeck();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Column(children: [
        _buildHeader(),
        _buildModoSelector(),
        _buildSubTabs(),
        Expanded(child: _subTab == 0 ? _buildDeck() : _buildBandeja()),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: KoraColors.bg,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(children: [
        const Text('Descubrir',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: KoraColors.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: _abrirFiltros,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: KoraColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KoraColors.divider),
            ),
            child: const Icon(Icons.tune_rounded, color: KoraColors.textSecondary, size: 20),
          ),
        ),
      ]),
    );
  }

  void _abrirFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KoraColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: KoraColors.divider,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              const Text('Filtros', style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w900, color: KoraColors.textPrimary,
                  letterSpacing: -0.5)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setLocal(() {
                    _edadRange = const RangeValues(18, 30);
                    _distanciaMax = 10;
                    _carreras = {};
                  });
                  setState(() {});
                },
                child: const Text('Limpiar', style: TextStyle(
                    color: KoraColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 24),

            // Rango edad
            Row(children: [
              const Icon(Icons.cake_rounded, size: 16, color: KoraColors.textHint),
              const SizedBox(width: 8),
              const Text('Edad', style: TextStyle(color: KoraColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text('${_edadRange.start.round()} - ${_edadRange.end.round()} años',
                  style: const TextStyle(color: KoraColors.primary,
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            RangeSlider(
              values: _edadRange, min: 17, max: 45, divisions: 28,
              activeColor: KoraColors.primary,
              inactiveColor: KoraColors.bgElevated,
              onChanged: (v) {
                setLocal(() => _edadRange = v);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            // Distancia
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 16, color: KoraColors.textHint),
              const SizedBox(width: 8),
              const Text('Distancia máx', style: TextStyle(color: KoraColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text('${_distanciaMax.round()} km',
                  style: const TextStyle(color: KoraColors.primary,
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            Slider(
              value: _distanciaMax, min: 1, max: 50, divisions: 49,
              activeColor: KoraColors.primary,
              inactiveColor: KoraColors.bgElevated,
              onChanged: (v) {
                setLocal(() => _distanciaMax = v);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            // Carreras
            Align(
              alignment: Alignment.centerLeft,
              child: Row(children: [
                const Icon(Icons.school_rounded, size: 16, color: KoraColors.textHint),
                const SizedBox(width: 8),
                const Text('Carreras', style: TextStyle(color: KoraColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              'Ingeniería', 'Derecho', 'Medicina', 'Psicología',
              'Administración', 'Diseño', 'Comunicación', 'Economía',
            ].map((c) {
              final sel = _carreras.contains(c);
              return GestureDetector(
                onTap: () {
                  setLocal(() {
                    sel ? _carreras.remove(c) : _carreras.add(c);
                  });
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? KoraGradients.mainGradient : null,
                    color: sel ? null : KoraColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: sel ? null : Border.all(color: KoraColors.divider),
                  ),
                  child: Text(c, style: TextStyle(
                    color: sel ? Colors.white : KoraColors.textSecondary,
                    fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              );
            }).toList()),
            const SizedBox(height: 28),

            // Aplicar
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: KoraGradients.mainGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: KoraColors.primary.withOpacity(0.3),
                      blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<MatchingProvider>().cargarDeck();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Aplicar filtros',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildModoSelector() {
    final mp = context.watch<MatchingProvider>();

    // Todavía cargando intenciones del backend → skeleton
    if (!mp.intencionesListas) {
      return Container(
        color: KoraColors.bg,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: KoraColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    final modos = mp.modosDisponibles;

    // Sin intenciones después de cargar → error de red o perfil incompleto
    if (modos.isEmpty) {
      return const SizedBox.shrink(); // _buildDeck mostrará el estado de error
    }

    // Un solo modo → no mostrar selector, simplemente activarlo
    if (modos.length == 1) {
      if (mp.modo != modos.first) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) mp.setModo(modos.first);
        });
      }
      return const SizedBox.shrink();
    }

    const allModos  = ['pareja', 'amistad', 'estudio'];
    const allLabels = ['❤️ Pareja', '🤝 Amistad', '📚 Estudio'];

    final labels = allModos
        .asMap().entries
        .where((e) => modos.contains(e.value))
        .map((e) => allLabels[e.key])
        .toList();

    return Container(
      color: KoraColors.bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: List.generate(modos.length, (i) {
          final sel = mp.modo == modos[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => mp.setModo(modos[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < modos.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: sel ? KoraGradients.mainGradient : null,
                  color: sel ? null : KoraColors.bgElevated,
                  border: sel ? null : Border.all(color: KoraColors.divider),
                ),
                child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: sel ? Colors.white : KoraColors.textSecondary,
                  )),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSubTabs() {
    return Container(
      color: KoraColors.bg,
      child: Row(children: [
        _subTabBtn(0, 'Descubrir', Icons.explore_outlined),
        _subTabBtn(1, 'Likes', Icons.favorite_outline),
      ]),
    );
  }

  Widget _subTabBtn(int i, String label, IconData icon) {
    final sel = _subTab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _subTab = i);
          if (i == 1) context.read<MatchingProvider>().cargarBandeja();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: sel ? KoraColors.primary : KoraColors.divider, width: 2,
            )),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16,
              color: sel ? KoraColors.primary : KoraColors.textHint),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              color: sel ? KoraColors.primary : KoraColors.textHint,
            )),
          ]),
        ),
      ),
    );
  }

  // ── DECK ──────────────────────────────────────────────────────
  Widget _buildDeck() {
    final mp = context.watch<MatchingProvider>();

    if (mp.loading) return const Center(
        child: CircularProgressIndicator(color: KoraColors.primary, strokeWidth: 2));

    if (mp.error != null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: KoraColors.bgElevated,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded, size: 48, color: KoraColors.textHint),
        ),
        const SizedBox(height: 16),
        Text(mp.error!, style: const TextStyle(color: KoraColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        KoraButton(label: 'Reintentar', onPressed: mp.cargarDeck),
      ],
    ));

    if (mp.deck.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: KoraColors.bgElevated,
            shape: BoxShape.circle,
            border: Border.all(color: KoraColors.divider),
          ),
          child: const Text('🌵', style: TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: 24),
        const Text('Sin más perfiles por ahora',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: KoraColors.textPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text('Vuelve más tarde',
          style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 28),
        KoraButton(label: 'Actualizar', onPressed: mp.cargarDeck),
      ],
    ));

    final info = mp.likesInfo;
    return Column(children: [
      if (info != null)
        Container(
          color: KoraColors.bg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            _infoPill('${info['restantes']} likes', KoraColors.like, Icons.favorite),
            const Spacer(),
            if (info['superlike_disponible'] == true)
              _infoPill('Super Like', KoraColors.superlike, Icons.star),
          ]),
        ),
      Expanded(child: _SwipeCard(
        candidato: mp.deck.first,
        onSwipe: (a) => _doSwipe(mp, mp.deck.first.id, a),
      )),
    ]);
  }

  Widget _infoPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }

  Future<void> _doSwipe(MatchingProvider mp, int uid, String accion) async {
    final data = await mp.swipe(uid, accion);
    if (data == null || !mounted) return;
    if (data['match_creado'] == true) {
      _showMatchDialog(data['match']);
    }
  }

  void _showMatchDialog(Map<String, dynamic>? match) {
    Navigator.push(context, PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (ctx, _, __) => _MatchOverlay(match: match),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  // ── BANDEJA ───────────────────────────────────────────────────
  Widget _buildBandeja() {
    final mp = context.watch<MatchingProvider>();
    if (mp.likes.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('💌', style: TextStyle(fontSize: 56)),
          SizedBox(height: 20),
          Text('Sin likes pendientes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: KoraColors.textPrimary)),
          SizedBox(height: 6),
          Text('Cuando alguien te dé like aparecerá aquí',
            style: TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: mp.likes.length,
      itemBuilder: (ctx, i) {
        final like = mp.likes[i];
        final de   = like['de_usuario'] as Map<String, dynamic>;
        final superlike = like['superlike'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: KoraColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Stack(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: KoraColors.primary.withOpacity(0.12),
                  backgroundImage: de['foto_url'] != null
                      ? NetworkImage('${ApiClient.baseUrl}${de["foto_url"]}')
                      : null,
                  child: de['foto_url'] == null
                      ? Text((de['nombre'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                              color: KoraColors.primary))
                      : null,
                ),
                if (superlike)
                  Positioned(bottom: 0, right: 0, child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: KoraColors.superlike, shape: BoxShape.circle),
                    child: const Icon(Icons.star, size: 11, color: Colors.white),
                  )),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(de['nombre'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 15, color: KoraColors.textPrimary)),
                Text(de['carrera'] ?? '',
                  style: const TextStyle(color: KoraColors.textSecondary, fontSize: 12)),
                if (superlike)
                  const Text('⭐ Super Like!',
                    style: TextStyle(color: KoraColors.superlike,
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ])),
              Row(children: [
                _iconBtn(Icons.close_rounded, KoraColors.pass, 40,
                    () => _responder(mp, like['like_id'], 'rechazar')),
                const SizedBox(width: 8),
                if (like['modo'] == 'pareja') ...[
                  _iconBtn(Icons.people_rounded, KoraColors.primary, 36,
                      () => _responder(mp, like['like_id'], 'contrapropuesta')),
                  const SizedBox(width: 8),
                ],
                _iconBtn(Icons.favorite_rounded, KoraColors.match, 40,
                    () => _responder(mp, like['like_id'], 'aceptar')),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _iconBtn(IconData icon, Color color, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }

  Future<void> _responder(MatchingProvider mp, int likeId, String resp) async {
    final data = await mp.responderLike(likeId, resp);
    if (!mounted) return;
    if (data != null &&
        (data['resultado'] == 'match_creado' || data['resultado'] == 'match_amistad_creado')) {
      _showMatchDialog(data['match']);
    }
    if (resp == 'contrapropuesta') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Contrapropuesta enviada ✅'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KoraColors.bgElevated,
      ));
    }
  }
}

// ── Tarjeta de swipe ──────────────────────────────────────────────
class _SwipeCard extends StatefulWidget {
  final CandidatoModel candidato;
  final Function(String) onSwipe;
  const _SwipeCard({required this.candidato, required this.onSwipe});
  @override State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> with SingleTickerProviderStateMixin {
  double _dx = 0;
  double _dy = 0;
  double _snapFromDx = 0;
  double _snapFromDy = 0;
  late AnimationController _snapCtrl;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _snapCtrl.addListener(() {
      setState(() {
        _dx = _snapFromDx * (1 - _snapCtrl.value);
        _dy = _snapFromDy * (1 - _snapCtrl.value);
      });
    });
  }

  void _snapBack() {
    _snapFromDx = _dx;
    _snapFromDy = _dy;
    _snapCtrl.forward(from: 0);
  }

  @override
  void dispose() { _snapCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c      = widget.candidato;
    final foto   = c.fotos.isNotEmpty ? c.fotos.first : null;
    final angle  = _dx * 0.0015;
    final isLike = _dx > 40;
    final isPass = _dx < -40;

    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() { _dx += d.delta.dx; _dy += d.delta.dy * 0.3; }),
      onHorizontalDragEnd: (_) {
        if (_dx > 100)       { widget.onSwipe('like'); }
        else if (_dx < -100) { widget.onSwipe('pass'); }
        else                 { _snapBack(); }
      },
      child: Transform.translate(
        offset: Offset(_dx, _dy),
        child: Transform.rotate(
          angle: angle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(fit: StackFit.expand, children: [
                // Foto
                if (foto != null && foto['url'] != null)
                  Image.network(
                    '${ApiClient.baseUrl}${foto["url"]}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                else
                  _placeholder(),

                // Gradiente inferior
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: KoraGradients.cardGradient),
                ),

                // Badge LIKE
                if (isLike)
                  Positioned(top: 40, left: 24,
                    child: Transform.rotate(angle: -0.2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KoraColors.like, width: 3),
                        ),
                        child: const Text('LIKE',
                          style: TextStyle(color: KoraColors.like,
                              fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: 2)),
                      ))),

                // Badge NOPE
                if (isPass)
                  Positioned(top: 40, right: 24,
                    child: Transform.rotate(angle: 0.2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KoraColors.pass, width: 3),
                        ),
                        child: const Text('NOPE',
                          style: TextStyle(color: KoraColors.pass,
                              fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: 2)),
                      ))),

                // Info button
                Positioned(
                  top: 16, right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => UserDetailScreen(userId: c.id),
                    )),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.person_search_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),

                // Info inferior
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: scoreColor(c.scoreTotal).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.favorite, size: 12, color: Colors.white),
                            const SizedBox(width: 5),
                            Text('${c.scoreTotal.toStringAsFixed(0)}% compatible',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        // Nombre
                        Text(
                          '${c.nombre}${c.edad != null ? ", ${c.edad}" : ""}',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(c.carrera,
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14)),
                        if (c.bioCorta.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(c.bioCorta,
                            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        if (c.gustos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(spacing: 6, runSpacing: 6, children: c.gustos.take(4).map((g) =>
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Text(g, style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                            )
                          ).toList()),
                        ],
                        const SizedBox(height: 20),
                        // Botones de acción
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          _actionBtn(Icons.close_rounded, KoraColors.pass, 58,
                              () => widget.onSwipe('pass')),
                          _actionBtn(Icons.star_rounded, KoraColors.superlike, 46,
                              () => widget.onSwipe('superlike')),
                          _actionBtn(Icons.favorite_rounded, KoraColors.match, 58,
                              () => widget.onSwipe('like')),
                        ]),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: KoraColors.bgElevated,
    child: const Icon(Icons.person, size: 80, color: KoraColors.textHint),
  );

  Widget _actionBtn(IconData icon, Color color, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.5),
          border: Border.all(color: color.withOpacity(0.6), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, spreadRadius: 1),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }
}

// ── Overlay de match (pantalla completa) ─────────────────────────
class _MatchOverlay extends StatefulWidget {
  final Map<String, dynamic>? match;
  const _MatchOverlay({this.match});
  @override
  State<_MatchOverlay> createState() => _MatchOverlayState();
}

class _MatchOverlayState extends State<_MatchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final otro = widget.match?['otro_usuario'] as Map<String, dynamic>?;
    final fotoUrl = otro?['foto_url'] as String?;
    final nombre  = otro?['nombre'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withOpacity(0.92),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Confetti emoji
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 20),
                // Animated title
                ScaleTransition(
                  scale: _scale,
                  child: ShaderMask(
                    shaderCallback: (b) => KoraGradients.mainGradient.createShader(b),
                    child: const Text('¡Es un Match!',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -1)),
                  ),
                ),
                const SizedBox(height: 12),
                if (otro != null)
                  Text('Tú y $nombre se gustaron mutuamente 💜',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: KoraColors.textSecondary,
                        fontSize: 15, height: 1.5)),
                const SizedBox(height: 40),
                // Photo circles
                ScaleTransition(
                  scale: _scale,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _photoBubble(null, 'Tú', KoraColors.primary),
                      Transform.translate(
                        offset: const Offset(-20, 0),
                        child: _photoBubble(fotoUrl, nombre, KoraColors.accent),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(children: [
                    SizedBox(
                      width: double.infinity,
                      child: KoraGradientButton(
                        label: 'Enviar mensaje 💬',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KoraColors.textSecondary,
                          side: const BorderSide(color: KoraColors.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Seguir viendo',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoBubble(String? url, String name, Color borderColor) {
    return Container(
      width: 110, height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        color: KoraColors.bgElevated,
        boxShadow: [
          BoxShadow(color: borderColor.withOpacity(0.35), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: url != null
            ? Image.network('${ApiClient.baseUrl}$url', fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarLetter(name, borderColor))
            : _avatarLetter(name, borderColor),
      ),
    );
  }

  Widget _avatarLetter(String name, Color color) {
    return Container(
      color: color.withOpacity(0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
