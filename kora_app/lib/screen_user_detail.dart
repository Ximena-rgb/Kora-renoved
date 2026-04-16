import 'package:flutter/material.dart';
import 'api_client.dart';
import 'theme.dart';

double _udToDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

Color _udScoreColor(double s) {
  if (s >= 70) return KoraColors.scoreHigh;
  if (s >= 40) return KoraColors.scoreMid;
  return KoraColors.scoreLow;
}

class UserDetailScreen extends StatefulWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});
  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: FutureBuilder<dynamic>(
        future: ApiClient.get('/api/v1/users/${widget.userId}/'),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Stack(children: [
              Container(color: KoraColors.bg),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KoraColors.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              const Center(child: CircularProgressIndicator(color: KoraColors.primary, strokeWidth: 2)),
            ]);
          }
          if (snap.hasError) {
            return Scaffold(
              backgroundColor: KoraColors.bg,
              appBar: AppBar(backgroundColor: KoraColors.bg,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('😕', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  const Text('No se pudo cargar el perfil',
                      style: TextStyle(color: KoraColors.textSecondary, fontSize: 15)),
                ],
              )),
            );
          }
          final u = snap.data as Map<String, dynamic>;
          final fotos = List<Map<String, dynamic>>.from(u['fotos'] ?? []);
          final gustos = List<String>.from(u['gustos'] ?? []);
          final score = _udToDouble(u['reputacion']);
          final scoreTotal = _udToDouble(u['score_total']);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 440,
                pinned: true,
                backgroundColor: KoraColors.bg,
                surfaceTintColor: Colors.transparent,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo
                      fotos.isNotEmpty
                          ? GestureDetector(
                              onTapDown: (d) {
                                final w = MediaQuery.of(context).size.width;
                                setState(() {
                                  if (d.localPosition.dx > w / 2) {
                                    _photoIndex = (_photoIndex + 1).clamp(0, fotos.length - 1);
                                  } else {
                                    _photoIndex = (_photoIndex - 1).clamp(0, fotos.length - 1);
                                  }
                                });
                              },
                              child: Image.network(
                                '${ApiClient.baseUrl}${fotos[_photoIndex]["url"]}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _photoPlaceholder(u),
                              ),
                            )
                          : _photoPlaceholder(u),
                      // Gradient overlay
                      const DecoratedBox(
                        decoration: BoxDecoration(gradient: KoraGradients.cardGradient),
                      ),
                      // Photo indicator dots
                      if (fotos.length > 1)
                        Positioned(
                          top: 64, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(fotos.length, (i) =>
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _photoIndex ? 20 : 6, height: 4,
                                decoration: BoxDecoration(
                                  color: i == _photoIndex ? Colors.white : Colors.white38,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            ),
                          ),
                        ),
                      // Name overlay at bottom
                      Positioned(
                        bottom: 24, left: 20, right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (scoreTotal > 0)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _udScoreColor(scoreTotal).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.favorite, size: 12, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text('${scoreTotal.toStringAsFixed(0)}% compatible',
                                    style: const TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w700, fontSize: 12)),
                                ]),
                              ),
                            Text(
                              '${u['nombre'] ?? ''}${u['edad'] != null ? ", ${u['edad']}" : ""}',
                              style: const TextStyle(color: Colors.white, fontSize: 30,
                                  fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(u['carrera'] ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info chips
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _infoBadge(Icons.school_rounded,
                            'Semestre ${u['semestre'] ?? '?'}', KoraColors.primary),
                        if ((u['facultad'] ?? '').toString().isNotEmpty)
                          _infoBadge(Icons.business_rounded,
                              u['facultad'].toString(), const Color(0xFF0A84FF)),
                        if (score > 0)
                          _infoBadge(Icons.star_rounded,
                              '${score.toStringAsFixed(1)} reputación', KoraColors.accentGold),
                      ]),
                      const SizedBox(height: 22),
                      // Bio
                      if ((u['bio'] ?? u['bio_corta'] ?? '').toString().trim().isNotEmpty) ..._bioSection(u),
                      // Interests
                      if (gustos.isNotEmpty) ..._interestsSection(gustos),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bioSection(Map<String, dynamic> u) {
    final bio = (u['bio'] ?? u['bio_corta'] ?? '').toString().trim();
    return [
      const Text('Sobre mí',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KoraColors.textPrimary)),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KoraColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KoraColors.divider),
        ),
        child: Text(bio,
            style: const TextStyle(color: KoraColors.textSecondary, fontSize: 14, height: 1.6)),
      ),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _interestsSection(List<String> gustos) {
    return [
      const Text('Intereses',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KoraColors.textPrimary)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: gustos.map((g) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: KoraColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: KoraColors.primary.withOpacity(0.25)),
          ),
          child: Text(g, style: const TextStyle(
              color: KoraColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w500)),
        )).toList(),
      ),
    ];
  }

  Widget _photoPlaceholder(Map<String, dynamic> u) {
    final letter = (u['nombre'] ?? '?').toString();
    return Container(
      color: KoraColors.bgElevated,
      child: Center(
        child: Text(
          letter.isNotEmpty ? letter[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 90, color: KoraColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
