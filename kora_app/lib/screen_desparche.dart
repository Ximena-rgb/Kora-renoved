import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_desparche.dart';

class DesparcheScreen extends StatelessWidget {
  final String roomId;
  const DesparcheScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DesparcheProvider(roomId: roomId),
      child: const _DesparcheView(),
    );
  }
}

class _DesparcheView extends StatelessWidget {
  const _DesparcheView();

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DesparcheProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Text('🎮 ', style: TextStyle(fontSize: 20)),
          Text('Modo Desparche', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: dp.sesion == null ? _buildMenuJuegos(context, dp) : _buildJuego(context, dp),
    );
  }

  Widget _buildMenuJuegos(BuildContext context, DesparcheProvider dp) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: KoraGradients.subtleGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            const Text('🎲', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('¡A jugar!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: KoraColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Elige un juego para animar el chat',
              style: TextStyle(color: KoraColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 24),
        _juegoCard(context, dp,
          emoji: '😂',
          titulo: 'Verdad o Reto',
          descripcion: 'Responde una verdad incómoda o completa un reto divertido',
          tipo: 'verdad_o_reto',
          color: const Color(0xFFFF6B6B),
        ),
        const SizedBox(height: 12),
        _juegoCard(context, dp,
          emoji: '🤔',
          titulo: '¿Quién es más probable?',
          descripcion: 'Voten quién del grupo haría cierta cosa',
          tipo: 'quien_mas_probable',
          color: const Color(0xFF4ECDC4),
        ),
        const SizedBox(height: 12),
        _juegoCard(context, dp,
          emoji: '📸',
          titulo: 'Adivina la Foto',
          descripcion: 'Adivina a quién pertenece el detalle de la foto',
          tipo: 'adivina_foto',
          color: const Color(0xFF45B7D1),
        ),
        if (dp.error != null) ...[
          const SizedBox(height: 12),
          Text(dp.error!, style: const TextStyle(color: KoraColors.pass)),
        ],
      ]),
    );
  }

  Widget _juegoCard(BuildContext context, DesparcheProvider dp, {
    required String emoji, required String titulo,
    required String descripcion, required String tipo, required Color color,
  }) {
    return GestureDetector(
      onTap: dp.loading ? null : () => dp.crearSesion(tipo),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: KoraColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: KoraColors.bgCard.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 15, color: KoraColors.textPrimary)),
            const SizedBox(height: 3),
            Text(descripcion, style: const TextStyle(color: KoraColors.textSecondary,
                fontSize: 12)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 14, color: color),
        ]),
      ),
    );
  }

  Widget _buildJuego(BuildContext context, DesparcheProvider dp) {
    final sesion = dp.sesion!;
    final ronda  = sesion['ronda_actual_data'] as Map<String, dynamic>?;

    return Column(children: [
      // Header del juego
      Container(
        color: KoraColors.bgCard,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: KoraGradients.mainGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Ronda ${sesion["ronda_actual"]}/${sesion["max_rondas"]}',
              style: const TextStyle(color: KoraColors.bgCard, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const Spacer(),
          Text(sesion['tipo_display'] ?? '', style: const TextStyle(
              color: KoraColors.textSecondary, fontSize: 13)),
        ]),
      ),
      // Jugadores
      Container(
        height: 60, color: KoraColors.bg,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: (sesion['jugadores'] as List).length,
          itemBuilder: (_, i) {
            final j = (sesion['jugadores'] as List)[i] as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(right: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 16,
                  backgroundColor: KoraColors.primary.withOpacity(0.1),
                  child: Text((j['nombre'] as String)[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        color: KoraColors.primary, fontSize: 14))),
                Text('${j["puntos"]}pts',
                  style: const TextStyle(fontSize: 10, color: KoraColors.textSecondary)),
              ]),
            );
          },
        ),
      ),
      // Contenido de la ronda
      Expanded(
        child: ronda == null
            ? _buildEsperandoRonda(dp)
            : _buildRondaActual(context, dp, ronda),
      ),
    ]);
  }

  Widget _buildEsperandoRonda(DesparcheProvider dp) {
    if (!dp.sesionIniciada) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Esperando jugadores...', style: TextStyle(fontSize: 16,
            color: KoraColors.textSecondary)),
        const SizedBox(height: 20),
        if (dp.soyCreador)
          KoraGradientButton(
            label: 'Iniciar juego',
            onPressed: () => dp.iniciarSesion(),
            loading: dp.loading,
          ),
      ]));
    }
    return const Center(child: CircularProgressIndicator(color: KoraColors.primary));
  }

  Widget _buildRondaActual(BuildContext context, DesparcheProvider dp,
      Map<String, dynamic> ronda) {
    final tipo = ronda['tipo'] as String;
    final contenido = ronda['contenido'] as String;
    final dest = ronda['destinatario'] as Map<String, dynamic>?;

    Color cardColor;
    String emoji;
    switch (tipo) {
      case 'verdad': cardColor = const Color(0xFFFF6B6B); emoji = '🤫'; break;
      case 'reto':   cardColor = const Color(0xFF4ECDC4); emoji = '😈'; break;
      default:       cardColor = KoraColors.primary;       emoji = '🤔'; break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Spacer(),
        // Card de la ronda
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardColor.withOpacity(0.3), width: 2),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            if (dest != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Para: ${dest["nombre"]}',
                  style: TextStyle(color: cardColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              tipo == 'verdad' ? 'VERDAD' : tipo == 'reto' ? 'RETO' : '¿QUIÉN?',
              style: TextStyle(color: cardColor, fontWeight: FontWeight.w900,
                  fontSize: 13, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            contenido == '⏳ Generando con IA...'
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cardColor)),
                    const SizedBox(width: 8),
                    Text('Generando...', style: TextStyle(color: cardColor)),
                  ])
                : Text(contenido,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                        color: KoraColors.textPrimary, height: 1.4)),
          ]),
        ),
        const Spacer(),
        // Votos si es ¿Quién es más probable?
        if (tipo == 'pregunta' && (ronda['votos'] as List).isNotEmpty) ...[
          const Text('Votos:', style: TextStyle(fontWeight: FontWeight.w600,
              color: KoraColors.textSecondary)),
          const SizedBox(height: 8),
          ...((ronda['votos'] as List).take(3).map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(child: Text(v['votado__nombre'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500))),
              Text('${v["total"]} votos',
                style: const TextStyle(color: KoraColors.textSecondary)),
            ]),
          ))),
          const SizedBox(height: 12),
        ],
        // Botones
        Row(children: [
          if (tipo == 'pregunta')
            Expanded(child: OutlinedButton(
              onPressed: () => _mostrarVotacion(context, dp, ronda),
              child: const Text('Votar'),
            ))
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: KoraGradientButton(
              label: dp.sesion!['hay_mas'] == true
                  ? 'Siguiente ronda ▶' : 'Ver resultados 🏆',
              onPressed: () => dp.sesion!['hay_mas'] == true
                  ? dp.siguienteRonda() : dp.verResultados(context),
              loading: dp.loading,
            ),
          ),
        ]),
      ]),
    );
  }

  void _mostrarVotacion(BuildContext context, DesparcheProvider dp,
      Map<String, dynamic> ronda) {
    final jugadores = (dp.sesion!['jugadores'] as List);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('¿Quién es más probable?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...jugadores.map((j) => ListTile(
            leading: CircleAvatar(child: Text((j['nombre'] as String)[0])),
            title: Text(j['nombre'] ?? ''),
            onTap: () {
              Navigator.pop(context);
              dp.votar(ronda['id'], j['id']);
            },
          )),
        ]),
      ),
    );
  }
}
