import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'model_user.dart';
import 'provider_auth.dart';
import 'widget_campus_map.dart';
import 'widgets_kora_auth.dart';

/// Botón de estado + ubicación que aparece en el header principal.
///
/// Estados manuales (el usuario los elige):
///   🟢 Disponible  — libre para conectar
///   🟡 Ocupado     — presente pero no disponible
///   🔴 Ausente     — fuera del campus / no molestar
///
/// Estado automático (no editable):
///   📚 En clases   — se activa cuando el horario guardado coincide con la hora actual
///
/// El widget se re-evalúa cada minuto para detectar cambios de bloque de clase.
class EstadoBoton extends StatefulWidget {
  const EstadoBoton({super.key});

  @override
  State<EstadoBoton> createState() => _EstadoBotonState();
}

class _EstadoBotonState extends State<EstadoBoton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Revisar cada minuto si hay cambio de clase
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Helpers visuales ──────────────────────────────────────────

  Color _colorEstado(EstadoUsuario e) {
    switch (e) {
      case EstadoUsuario.disponible: return KoraColors.like;           // verde
      case EstadoUsuario.ocupado:    return KoraColors.accentGold;     // amarillo
      case EstadoUsuario.ausente:    return KoraColors.accent;         // rojo
      case EstadoUsuario.enClases:   return KoraColors.primary;        // violeta
    }
  }

  IconData _iconEstado(EstadoUsuario e) {
    switch (e) {
      case EstadoUsuario.disponible: return Icons.check_circle_rounded;
      case EstadoUsuario.ocupado:    return Icons.do_not_disturb_on_rounded;
      case EstadoUsuario.ausente:    return Icons.radio_button_unchecked_rounded;
      case EstadoUsuario.enClases:   return Icons.menu_book_rounded;
    }
  }

  String _bloqueLabel(String zona) {
    // Nombres cortos para el chip de ubicación (fuente oficial: pascualbravo.edu.co/campus)
    const nombres = {
      'b1':  'ITI Pascual Bravo', 'b2':  'Académico',      'b3':  'Complejo Acuático',
      'b4':  'Lab. LIDA',         'b5':  'Cientic',         'b6':  'Académico',
      'b7':  'Bienestar',         'b8':  'Parque Tech',     'b9':  'Lab. Dibujo/CAD',
      'b10': 'Proc. Eléctricos',  'b11': 'T. Automotriz',  'b12': 'C.I. Energía Elec.',
      'b13': 'Esc. P. Diseño',    'b14': 'Lab. Textil',    'b15': 'Lab. DIPMA',
      'b16': 'Imprenta/Logística','b17': 'CIDES Soldadura','b18': 'T. Máq. MEC',
      'b19': 'C.I. Materialog.',  'b20': 'Cancha Fútbol',  'b21': 'Coliseo Cubierto',
      'b22': 'Gimnasio',          'b23': 'Teatro Convención','b24': 'Biblioteca',
      'b25': 'Administrativo',    'b26': 'Ciudadela PNG',  'b27': 'Zona Comidas',
      'general': 'Campus',
    };
    return nombres[zona] ?? zona;
  }

  // ── Modal de selección de estado ─────────────────────────────

  void _abrirModalEstado(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final estadoActual = auth.user?.estado ?? EstadoUsuario.ausente;
    final enClases = auth.user?.estaEnClasesAhora ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EstadoSelectorSheet(
        estadoActual: estadoActual,
        enClasesAhora: enClases,
        onEstadoSeleccionado: (e) async {
          await auth.updateEstado(e);
        },
        onAbrirUbicacion: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 200), () {
            _abrirModalUbicacion(context);
          });
        },
        colorEstado: _colorEstado,
        iconEstado: _iconEstado,
      ),
    );
  }

  // ── Modal de ubicación (bloque campus) ────────────────────────

  void _abrirModalUbicacion(BuildContext context) {
    final auth = context.read<AuthProvider>();
    String bloqueTemp = auth.user?.campus_zona ?? 'general';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: KoraColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                const Text('¿Dónde estás?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: KoraColors.textPrimary)),
                const Spacer(),
                if (bloqueTemp.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: KoraGradients.mainGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_bloqueLabel(bloqueTemp),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Toca tu bloque en el mapa del campus.',
                style: TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CampusMapWidget(
                bloqueSeleccionado: bloqueTemp,
                onBloqueSelected: (b) => setS(() => bloqueTemp = b),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KoraGradientButton(
                label: 'Confirmar ubicación',
                loading: false,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.read<AuthProvider>().updateCampusZona(bloqueTemp);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final user  = auth.user;
    if (user == null) return const SizedBox.shrink();

    final estadoEfectivo = user.estadoEfectivo;
    final color          = _colorEstado(estadoEfectivo);
    final zona           = user.campus_zona;
    final tieneZona      = zona.isNotEmpty && zona != 'general';
    final enClases       = user.estaEnClasesAhora;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      // ── Chip de ubicación ───────────────────────────────────
      GestureDetector(
        onTap: () => _abrirModalUbicacion(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: tieneZona
                ? KoraColors.primary.withOpacity(0.10)
                : KoraColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tieneZona
                  ? KoraColors.primary.withOpacity(0.35)
                  : KoraColors.divider,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_rounded,
                size: 13,
                color: tieneZona ? KoraColors.primary : KoraColors.textHint),
            const SizedBox(width: 4),
            Text(
              tieneZona ? _bloqueLabel(zona) : 'Ubicación',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tieneZona ? KoraColors.primary : KoraColors.textHint,
              ),
            ),
          ]),
        ),
      ),

      const SizedBox(width: 8),

      // ── Chip de estado (toca para cambiar) ──────────────────
      GestureDetector(
        onTap: enClases
            ? null   // No se puede cambiar manualmente mientras hay clase
            : () => _abrirModalEstado(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.40)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // Dot animado para Disponible; estático para otros estados
            if (estadoEfectivo == EstadoUsuario.disponible)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(_pulse.value),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35 * _pulse.value),
                        blurRadius: 5, spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              )
            else
              Icon(_iconEstado(estadoEfectivo), size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              estadoEfectivo.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            // Chevron solo cuando es editable
            if (!enClases) ...[
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: color.withOpacity(0.7)),
            ],
          ]),
        ),
      ),
    ]);
  }
}


// ── Sheet de selección de estado ──────────────────────────────────
class _EstadoSelectorSheet extends StatelessWidget {
  final EstadoUsuario estadoActual;
  final bool enClasesAhora;
  final ValueChanged<EstadoUsuario> onEstadoSeleccionado;
  final VoidCallback onAbrirUbicacion;
  final Color Function(EstadoUsuario) colorEstado;
  final IconData Function(EstadoUsuario) iconEstado;

  const _EstadoSelectorSheet({
    required this.estadoActual,
    required this.enClasesAhora,
    required this.onEstadoSeleccionado,
    required this.onAbrirUbicacion,
    required this.colorEstado,
    required this.iconEstado,
  });

  static const _opcionesEditables = [
    EstadoUsuario.disponible,
    EstadoUsuario.ocupado,
    EstadoUsuario.ausente,
  ];

  static const _descripcionEstado = {
    EstadoUsuario.disponible: 'Apareces en el mapa y puedes recibir conexiones.',
    EstadoUsuario.ocupado:    'Visible pero no disponible para conectar ahora.',
    EstadoUsuario.ausente:    'No apareces en el mapa ni recibes solicitudes.',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: KoraColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '¿Cuál es tu estado?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: KoraColors.textPrimary,
            ),
          ),
        ),

        // Banner informativo si hay clase activa
        if (enClasesAhora) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: KoraColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KoraColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.menu_book_rounded, size: 16, color: KoraColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Estás en clases ahora. El estado se restaurará automáticamente al terminar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: KoraColors.primary.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 16),

        // Opciones de estado
        ..._opcionesEditables.map((e) {
          final isSelected = estadoActual == e && !enClasesAhora;
          final color      = colorEstado(e);
          return _EstadoOpcion(
            estado:     e,
            isSelected: isSelected,
            color:      color,
            icon:       iconEstado(e),
            descripcion: _descripcionEstado[e] ?? '',
            onTap: () {
              onEstadoSeleccionado(e);
              Navigator.pop(context);
            },
          );
        }),

        const SizedBox(height: 8),

        // Acceso rápido a ubicación
        GestureDetector(
          onTap: onAbrirUbicacion,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KoraColors.bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KoraColors.divider),
            ),
            child: Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 18, color: KoraColors.textSecondary),
              const SizedBox(width: 12),
              Text('Actualizar mi ubicación',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KoraColors.textSecondary,
                )),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: KoraColors.textHint),
            ]),
          ),
        ),
      ]),
    );
  }
}


class _EstadoOpcion extends StatelessWidget {
  final EstadoUsuario estado;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final String descripcion;
  final VoidCallback onTap;

  const _EstadoOpcion({
    required this.estado,
    required this.isSelected,
    required this.color,
    required this.icon,
    required this.descripcion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.10) : KoraColors.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.45) : KoraColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Ícono con fondo
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(estado.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : KoraColors.textPrimary,
                  )),
                const SizedBox(height: 2),
                Text(descripcion,
                  style: TextStyle(
                    fontSize: 12,
                    color: KoraColors.textSecondary,
                    height: 1.3,
                  )),
              ],
            ),
          ),
          // Check si está seleccionado
          if (isSelected)
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 13, color: Colors.white),
            ),
        ]),
      ),
    );
  }
}
