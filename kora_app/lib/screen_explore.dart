import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_matching.dart';
import 'api_client.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  final _filtros = ['18-24 y.o.', 'Dating', "Don't drink"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchingProvider>().cargarDeck();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mp = context.watch<MatchingProvider>();

    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: CustomScrollView(slivers: [
        // Header "Explore" grande + ícono filtro
        SliverAppBar(
          backgroundColor: KoraColors.bg,
          pinned: true, floating: false,
          titleSpacing: 20,
          expandedHeight: 60,
          title: const Text('Explore', style: TextStyle(
              color: KoraColors.textPrimary, fontSize: 34,
              fontWeight: FontWeight.w900)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 8),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: KoraColors.bgCard,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune,
                    color: KoraColors.textSecondary, size: 18)),
            ),
          ],
        ),

        // Filtros pill con X
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _filtros.map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: KoraColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KoraColors.divider)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.close, size: 13,
                      color: KoraColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(f, style: const TextStyle(
                      color: KoraColors.textSecondary, fontSize: 13,
                      fontWeight: FontWeight.w500)),
                ])),
            )).toList()),
          ),
        )),

        // Grid 2 columnas
        if (mp.loading)
          const SliverFillRemaining(child: Center(
              child: CircularProgressIndicator(color: KoraColors.like)))
        else
          SliverPadding(
            padding: EdgeInsets.only(
                left: 12, right: 12,
                bottom: MediaQuery.of(context).padding.bottom + 90),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  if (mp.deck.isEmpty) return const SizedBox();
                  final c = mp.deck[i % mp.deck.length];
                  // Colores de fondo variados como en la imagen
                  final colors = [
                    const Color(0xFFC0392B),  // rojo oscuro
                    const Color(0xFF1A3A5C),  // azul oscuro
                    const Color(0xFF2C1A4A),  // morado oscuro
                    const Color(0xFF1A4A2C),  // verde oscuro
                  ];
                  return _ExploreCard(
                    candidato: c,
                    bgColor: colors[i % colors.length],
                    onLike: () {},
                  );
                },
                childCount: mp.deck.isEmpty ? 0 : mp.deck.length,
              ),
            ),
          ),
      ]),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final CandidatoModel candidato;
  final Color bgColor;
  final VoidCallback onLike;
  const _ExploreCard({required this.candidato, required this.bgColor,
      required this.onLike});

  @override
  Widget build(BuildContext context) {
    final c    = candidato;
    final foto = c.fotos.isNotEmpty ? c.fotos.first : null;

    return GestureDetector(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: bgColor,
          child: Stack(fit: StackFit.expand, children: [
            // Foto
            if (foto != null && foto['url'] != null)
              Image.network('${ApiClient.baseUrl}${foto["url"]}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),

            // Gradiente inferior
            const DecoratedBox(decoration: BoxDecoration(
                gradient: KoraGradients.cardOverlay)),

            // Nombre en bold blanco abajo-izquierda
            Positioned(bottom: 44, left: 12, right: 44,
              child: Text(
                c.nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )),

            // Botón ❤️ circular — esquina inferior derecha
            Positioned(bottom: 10, right: 10,
              child: GestureDetector(
                onTap: onLike,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.favorite,
                      color: KoraColors.like, size: 19)))),
          ]),
        ),
      ),
    );
  }
}
