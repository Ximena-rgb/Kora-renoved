import 'package:flutter/material.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────────
// Datos de cada bloque del campus Pascual Bravo
// Nombres según lista oficial: pascualbravo.edu.co/campus-universitario
// ─────────────────────────────────────────────────────────────────
class _BloqueInfo {
  final String id;
  final int    numero;
  final String nombre;
  final String descripcion;
  final String categoria;
  final Color  color;
  const _BloqueInfo({
    required this.id, required this.numero, required this.nombre,
    required this.descripcion, required this.categoria, required this.color,
  });
}

const _kAzul     = Color(0xFF3A8FD4);
const _kAmarillo = Color(0xFFE8C22A);
const _kNaranja  = Color(0xFFD45A30);
const _kOscuro   = Color(0xFF1A2535);
const _kCian     = Color(0xFF17B7C4);

const List<_BloqueInfo> _kBloques = [
  _BloqueInfo(id:'b1',  numero:1,  nombre:'Instituto Técnico Industrial Pascual Bravo',
    descripcion:'I.E. Instituto Técnico Industrial Pascual Bravo. Sede del colegio articulado.',
    categoria:'admin',    color:_kCian),
  _BloqueInfo(id:'b2',  numero:2,  nombre:'Bloque 2 — Académico',
    descripcion:'Edificio académico con aulas de clase y salones para diferentes programas.',
    categoria:'aula',     color:_kAzul),
  _BloqueInfo(id:'b3',  numero:3,  nombre:'Complejo Acuático',
    descripcion:'Piscina institucional y zonas de natación.',
    categoria:'deporte',  color:_kNaranja),
  _BloqueInfo(id:'b4',  numero:4,  nombre:'Lab. Diagnóstico Automotriz — LIDA',
    descripcion:'Laboratorio de Investigación y Diagnóstico Automotriz.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b5',  numero:5,  nombre:'Cientic',
    descripcion:'Centro de ciencia y tecnología. Espacios de innovación.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b6',  numero:6,  nombre:'Bloque 6 — Académico',
    descripcion:'Edificio académico con aulas de clase.',
    categoria:'aula',     color:_kAzul),
  _BloqueInfo(id:'b7',  numero:7,  nombre:'Bienestar Universitario',
    descripcion:'Servicios de salud, psicología, deporte y cultura.',
    categoria:'servicio', color:_kNaranja),
  _BloqueInfo(id:'b8',  numero:8,  nombre:'Parque Tech',
    descripcion:'Parque Tecnológico. Emprendimiento e innovación.',
    categoria:'servicio', color:_kNaranja),
  _BloqueInfo(id:'b9',  numero:9,  nombre:'Lab. Dibujo Técnico y CAD',
    descripcion:'Laboratorio de Dibujo Técnico y Diseño Asistido por Computador.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b10', numero:10, nombre:'Procesos Eléctricos',
    descripcion:'Laboratorio de Procesos Eléctricos.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b11', numero:11, nombre:'Taller Mecánica Automotriz',
    descripcion:'Taller de Mecánica Automotriz.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b12', numero:12, nombre:'Centro Energía Eléctrica',
    descripcion:'Centro de I+D en Procesos de Energía Eléctrica.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b13', numero:13, nombre:'Escuela Pública de Diseño',
    descripcion:'EPDI. Talleres de diseño gráfico, textil y comunicación visual.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b14', numero:14, nombre:'Laboratorio Textil',
    descripcion:'Maquinaria industrial de confección y tejido.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b15', numero:15, nombre:'Lab. Manufactura Avanzada — DIPMA',
    descripcion:'Desarrollo e I+D en Procesos de Manufactura Avanzada. CNC.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b16', numero:16, nombre:'Imprenta / Logística / Química',
    descripcion:'Imprenta institucional, Lab. Logística y Lab. Química y Física.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b17', numero:17, nombre:'Centro Soldadura — CIDES',
    descripcion:'Centro de I+D en Soldadura.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b18', numero:18, nombre:'Taller Máquinas y Herramientas — MEC',
    descripcion:'Tornos, fresadoras y equipos de precisión.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b19', numero:19, nombre:'Centro Materialografía',
    descripcion:'Centro de I+D en Materialografía.',
    categoria:'taller',   color:_kAmarillo),
  _BloqueInfo(id:'b20', numero:20, nombre:'Cancha Sintética de Fútbol',
    descripcion:'Cancha sintética de fútbol.',
    categoria:'deporte',  color:_kNaranja),
  _BloqueInfo(id:'b21', numero:21, nombre:'Coliseo Cubierto',
    descripcion:'Coliseo cubierto multiusos.',
    categoria:'deporte',  color:_kNaranja),
  _BloqueInfo(id:'b22', numero:22, nombre:'Gimnasio',
    descripcion:'Gimnasio institucional.',
    categoria:'deporte',  color:_kNaranja),
  _BloqueInfo(id:'b23', numero:23, nombre:'Teatro La Convención',
    descripcion:'Auditorio institucional. Eventos culturales y graduaciones.',
    categoria:'nuevo',    color:_kOscuro),
  _BloqueInfo(id:'b24', numero:24, nombre:'Biblioteca',
    descripcion:'Biblioteca y hemeroteca. Salas de lectura y bases de datos.',
    categoria:'servicio', color:_kCian),
  _BloqueInfo(id:'b25', numero:25, nombre:'Administrativo',
    descripcion:'Rectoría, Vicerrectorías y oficinas institucionales.',
    categoria:'admin',    color:_kOscuro),
  _BloqueInfo(id:'b26', numero:26, nombre:'Ciudadela Pedro Nel Gómez',
    descripcion:'Espacios académicos y culturales.',
    categoria:'aula',     color:_kAzul),
  _BloqueInfo(id:'b27', numero:27, nombre:'Zona de Comidas y Bienestar',
    descripcion:'Restaurante y espacios de bienestar y descanso.',
    categoria:'servicio', color:_kNaranja),
];

// ─────────────────────────────────────────────────────────────────
// Widget público
// ─────────────────────────────────────────────────────────────────
class CampusMapWidget extends StatefulWidget {
  final String bloqueSeleccionado;
  final Function(String) onBloqueSelected;
  const CampusMapWidget({
    super.key,
    required this.bloqueSeleccionado,
    required this.onBloqueSelected,
  });
  @override State<CampusMapWidget> createState() => _CampusMapWidgetState();
}

class _CampusMapWidgetState extends State<CampusMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  // Pan / zoom
  double _scale      = 1.0;
  Offset _offset     = Offset.zero;
  Offset _focalStart  = Offset.zero;
  Offset _offsetStart = Offset.zero;
  double _scaleStart  = 1.0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  _BloqueInfo? _bloqueById(String id) {
    try { return _kBloques.firstWhere((b) => b.id == id); } catch (_) { return null; }
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'aula':     return 'Aula';
      case 'taller':   return 'Taller / Lab.';
      case 'admin':    return 'Administrativo';
      case 'nuevo':    return 'Edificio nuevo';
      case 'servicio': return 'Servicio';
      case 'deporte':  return 'Deportes';
      default:         return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = _bloqueById(widget.bloqueSeleccionado);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Mapa con proporción correcta ─────────────────────────
      // El campus en el plano oficial es aproximadamente 930×1210px → ratio ~1:1.3
      // Usamos AspectRatio para respetar esa proporción en cualquier pantalla.
      AspectRatio(
        aspectRatio: 930 / 1210,   // ancho/alto del plano oficial
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D180D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KoraColors.primary.withOpacity(0.25)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onScaleStart: (d) {
                _focalStart  = d.localFocalPoint;
                _offsetStart = _offset;
                _scaleStart  = _scale;
              },
              onScaleUpdate: (d) {
                setState(() {
                  _scale  = (_scaleStart * d.scale).clamp(0.9, 3.5);
                  _offset = _offsetStart + (d.localFocalPoint - _focalStart);
                });
              },
              onDoubleTap: () => setState(() { _scale = 1.0; _offset = Offset.zero; }),
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => LayoutBuilder(
                  builder: (ctx, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return Stack(children: [
                      // Fondo + edificios pintados
                      Transform(
                        transform: Matrix4.identity()
                          ..translate(_offset.dx, _offset.dy)
                          ..scale(_scale),
                        child: CustomPaint(
                          size: Size(w, h),
                          painter: _CampusPainter(
                            selected:  widget.bloqueSeleccionado,
                            pulse:     _pulse.value,
                          ),
                        ),
                      ),
                      // Pines encima del transform
                      ..._kBloques.map((b) {
                        final pos = _pinPos(b.id, w, h);
                        final px  = pos.dx * _scale + _offset.dx - 11;
                        final py  = pos.dy * _scale + _offset.dy - 11;
                        final isSel = b.id == widget.bloqueSeleccionado;
                        return Positioned(
                          left: px, top: py,
                          child: GestureDetector(
                            onTap: () => widget.onBloqueSelected(b.id),
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSel
                                    ? KoraColors.primary
                                    : (b.numero == 1 || b.numero >= 23)
                                        ? _kCian
                                        : const Color(0xFF0F1E35),
                                border: Border.all(
                                  color: isSel ? Colors.white
                                      : Colors.white.withOpacity(0.65),
                                  width: isSel ? 2.5 : 1.5,
                                ),
                                boxShadow: isSel ? [BoxShadow(
                                  color: KoraColors.primary.withOpacity(
                                      0.55 * _pulse.value),
                                  blurRadius: 10, spreadRadius: 2,
                                )] : [],
                              ),
                              child: Center(child: Text('${b.numero}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: b.numero >= 10 ? 7.0 : 8.5,
                                  fontWeight: FontWeight.w900, height: 1,
                                ))),
                            ),
                          ),
                        );
                      }),
                    ]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),

      const SizedBox(height: 10),

      // ── Card del bloque seleccionado ─────────────────────────
      if (sel != null)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel.color.withOpacity(0.4), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: sel.color, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('${sel.numero}',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sel.nombre, style: const TextStyle(
                    color: KoraColors.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(sel.descripcion, style: const TextStyle(
                    color: KoraColors.textSecondary, fontSize: 11, height: 1.4)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sel.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(_catLabel(sel.categoria),
                    style: TextStyle(color: sel.color,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ])),
            GestureDetector(
              onTap: () => widget.onBloqueSelected(''),
              child: const Icon(Icons.close, size: 16, color: KoraColors.textHint)),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KoraColors.divider),
          ),
          child: Row(children: [
            const Icon(Icons.touch_app_outlined, size: 15, color: KoraColors.textHint),
            const SizedBox(width: 8),
            const Text('Toca un bloque para seleccionarlo',
              style: TextStyle(color: KoraColors.textHint, fontSize: 13)),
          ]),
        ),

      const SizedBox(height: 8),

      // ── Leyenda ───────────────────────────────────────────────
      Wrap(spacing: 14, runSpacing: 4, children: [
        _leg(_kAzul,     'Aulas'),
        _leg(_kAmarillo, 'Talleres/Labs'),
        _leg(_kNaranja,  'Servicios/Deporte'),
        _leg(_kOscuro,   'Admin./Nuevo'),
        _leg(_kCian,     'Especiales'),
      ]),
    ]);
  }

  Widget _leg(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: KoraColors.textSecondary)),
  ]);

  // ── Posiciones de pines normalizadas (0..1) ──────────────────
  // Basadas en el plano oficial del campus Pascual Bravo.
  // Coordenadas en el espacio de diseño 930×1210 → normalizadas a 0..1
  // x=0 izquierda, x=1 derecha; y=0 arriba, y=1 abajo
  Offset _pinPos(String id, double w, double h) {
    const p = {
      // Zona norte-oeste (bloques 7, 8, 27)
      'b7':  (0.08, 0.32),   // izquierda media-alta
      'b8':  (0.13, 0.18),   // norte izquierda (amarillo grande)
      'b27': (0.07, 0.40),   // naranja izquierda (zona comidas)
      // Zona central-norte (bloques 2, 6, amarillos)
      'b2':  (0.18, 0.37),   // amarillo centro-izq (académico)
      'b6':  (0.22, 0.29),   // amarillo centro-izq alto
      // Zona central (bloques 1, 3, 4, 5)
      'b1':  (0.19, 0.51),   // cian (ITI Pascual Bravo)
      'b3':  (0.27, 0.33),   // naranja (complejo acuático)
      'b4':  (0.22, 0.43),   // naranja-azul (LIDA)
      'b5':  (0.26, 0.39),   // amarillo pequeño (Cientic)
      // Bloques azules columna central-norte (9-12)
      'b9':  (0.32, 0.23),   // azul col
      'b10': (0.34, 0.29),   // azul col
      'b11': (0.40, 0.20),   // azul col
      'b12': (0.38, 0.27),   // azul col
      // Bloque 13 amarillo derecha alta
      'b13': (0.66, 0.17),   // amarillo grande derecha norte
      // Bloques azules columnas derecha (14-19)
      'b14': (0.55, 0.30),   // azul col derecha
      'b15': (0.59, 0.29),   // azul col derecha
      'b16': (0.63, 0.28),   // azul col derecha
      'b17': (0.63, 0.35),   // azul col derecha baja
      'b18': (0.59, 0.36),   // azul col derecha baja
      'b19': (0.55, 0.37),   // azul col derecha baja
      // Cancha y zonas deportivas (20-22)
      'b20': (0.68, 0.46),   // cancha fútbol (naranja grande)
      'b21': (0.56, 0.51),   // coliseo cubierto (oscuro centro)
      'b22': (0.68, 0.54),   // gimnasio
      // Zona sur-este (23-25 oscuros)
      'b23': (0.72, 0.72),   // teatro (oscuro)
      'b24': (0.63, 0.76),   // biblioteca (cian)
      'b25': (0.54, 0.73),   // administrativo (oscuro)
      // Zona sur-oeste (26)
      'b26': (0.27, 0.84),   // ciudadela PNG (naranja-L)
    };
    final raw = p[id] ?? (0.5, 0.5);
    return Offset(raw.$1 * w, raw.$2 * h);
  }
}

// ─────────────────────────────────────────────────────────────────
// Painter — dibuja el plano base del campus
// Diseño de referencia: 930×1210 (plano oficial Pascual Bravo)
// Las coordenadas están normalizadas a 0..1 y se escalan con w/h del canvas.
// ─────────────────────────────────────────────────────────────────
class _CampusPainter extends CustomPainter {
  final String selected;
  final double pulse;
  const _CampusPainter({required this.selected, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Fondo ────────────────────────────────────────────────────
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0D180D));

    // ── Contorno del campus (polígono irregular) ─────────────────
    // Basado en el contorno real del campus Pascual Bravo
    final campus = Path()
      ..moveTo(w*0.23, h*0.02)
      ..lineTo(w*0.77, h*0.02)
      ..lineTo(w*0.90, h*0.08)
      ..lineTo(w*0.97, h*0.22)
      ..lineTo(w*0.97, h*0.55)
      ..lineTo(w*0.92, h*0.72)
      ..lineTo(w*0.88, h*0.97)
      ..lineTo(w*0.18, h*0.97)
      ..lineTo(w*0.05, h*0.87)
      ..lineTo(w*0.03, h*0.60)
      ..lineTo(w*0.03, h*0.35)
      ..lineTo(w*0.10, h*0.15)
      ..close();
    canvas.drawPath(campus, Paint()..color = const Color(0xFF111E11));
    canvas.drawPath(campus, Paint()
      ..color = const Color(0xFF2A4A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // ── Zonas verdes ─────────────────────────────────────────────
    final grass = Paint()..color = const Color(0xFF193019);
    // Zona verde central (alrededor del bloque 1)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w*0.19, h*0.57), width: w*0.22, height: h*0.12),
      grass);
    // Zona verde entre bloques centrales
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w*0.46, h*0.55), width: w*0.10, height: h*0.06),
      grass);
    // Zona verde sur
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w*0.42, h*0.83), width: w*0.18, height: h*0.08),
      grass);
    // Zona verde rotonda sur
    canvas.drawCircle(Offset(w*0.42, h*0.68), w*0.05,
      Paint()..color = const Color(0xFF172817));

    // ── Vías principales ─────────────────────────────────────────
    final road = Paint()
      ..color = const Color(0xFF252520)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    // Vía vertical principal (norte-sur)
    canvas.drawLine(Offset(w*0.46, h*0.04), Offset(w*0.44, h*0.95), road);
    // Vía horizontal (este-oeste) media
    canvas.drawLine(Offset(w*0.06, h*0.46), Offset(w*0.94, h*0.46), road);
    // Vía diagonal sur-este
    canvas.drawLine(Offset(w*0.44, h*0.68), Offset(w*0.88, h*0.72), road);
    // Vía curva zona sur (hacia ciudadela)
    final curvaSur = Path()
      ..moveTo(w*0.30, h*0.70)
      ..cubicTo(w*0.34, h*0.76, w*0.38, h*0.82, w*0.26, h*0.90);
    canvas.drawPath(curvaSur, road);

    // ── Rotonda / glorieta ────────────────────────────────────────
    canvas.drawCircle(Offset(w*0.42, h*0.68), w*0.05,
        Paint()..color = const Color(0xFF1E1E18));
    canvas.drawCircle(Offset(w*0.42, h*0.68), w*0.05,
        Paint()..color = const Color(0xFF3A3A30)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // ═══════════════════════════════════════════════════════════
    // ── BLOQUES — posiciones fieles al plano oficial ──────────
    // Formato: _b(canvas, w, h, x, y, ancho, alto, color, id)
    // Coordenadas en porcentaje del canvas (0..1)
    // ═══════════════════════════════════════════════════════════

    // ── Bloque 8 — Parque Tech (amarillo grande, noroeste) ──────
    _b(canvas, w, h, 0.07, 0.10, 0.16, 0.10, const Color(0xFFE8C22A), 'b8');

    // ── Bloques 2 y 6 — Académico (amarillos centro-izq) ────────
    _b(canvas, w, h, 0.12, 0.27, 0.15, 0.08, const Color(0xFFE8C22A), 'b6');
    _b(canvas, w, h, 0.10, 0.33, 0.18, 0.10, const Color(0xFFE8C22A), 'b2');

    // ── Bloque 13 — Escuela Pública Diseño (amarillo derecha) ───
    _b(canvas, w, h, 0.54, 0.10, 0.24, 0.09, const Color(0xFFE8C22A), 'b13');

    // ── Bloques azules columna izquierda (9-10, 5) ───────────────
    _b(canvas, w, h, 0.30, 0.17, 0.06, 0.14, const Color(0xFF3A8FD4), 'b9');
    _b(canvas, w, h, 0.32, 0.25, 0.05, 0.10, const Color(0xFF3A8FD4), 'b10');
    _b(canvas, w, h, 0.24, 0.34, 0.05, 0.10, const Color(0xFF3A8FD4), 'b5');

    // ── Bloques azules columna media (11-12) ─────────────────────
    _b(canvas, w, h, 0.37, 0.16, 0.06, 0.14, const Color(0xFF3A8FD4), 'b11');
    _b(canvas, w, h, 0.36, 0.24, 0.05, 0.10, const Color(0xFF3A8FD4), 'b12');

    // ── Bloques azules columnas derecha (14-19) ──────────────────
    _b(canvas, w, h, 0.52, 0.24, 0.05, 0.14, const Color(0xFF3A8FD4), 'b14');
    _b(canvas, w, h, 0.57, 0.24, 0.05, 0.13, const Color(0xFF3A8FD4), 'b15');
    _b(canvas, w, h, 0.61, 0.22, 0.06, 0.15, const Color(0xFF3A8FD4), 'b16');
    _b(canvas, w, h, 0.61, 0.31, 0.06, 0.10, const Color(0xFF3A8FD4), 'b17');
    _b(canvas, w, h, 0.57, 0.32, 0.05, 0.10, const Color(0xFF3A8FD4), 'b18');
    _b(canvas, w, h, 0.52, 0.33, 0.05, 0.10, const Color(0xFF3A8FD4), 'b19');

    // ── Bloques naranjas (3, 4, 7, 27) ───────────────────────────
    _b(canvas, w, h, 0.25, 0.27, 0.05, 0.08, const Color(0xFFD45A30), 'b3');
    _b(canvas, w, h, 0.19, 0.38, 0.06, 0.09, const Color(0xFFD45A30), 'b4');
    _b(canvas, w, h, 0.04, 0.26, 0.06, 0.09, const Color(0xFFD45A30), 'b7');
    // b27 forma L (zona comidas)
    _bL(canvas, w, h, 0.04, 0.35, 0.08, 0.08, const Color(0xFFD45A30), 'b27');

    // ── Cancha fútbol (bloque 20) ─────────────────────────────────
    _b(canvas, w, h, 0.50, 0.41, 0.28, 0.13, const Color(0xFFBB4422), 'b20');
    // líneas de la cancha
    final lp = Paint()..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke..strokeWidth = 0.8;
    canvas.drawRect(Rect.fromLTWH(w*0.51, h*0.42, w*0.26, h*0.11), lp);
    canvas.drawLine(Offset(w*0.64, h*0.42), Offset(w*0.64, h*0.53), lp);
    canvas.drawCircle(Offset(w*0.64, h*0.475), w*0.03, lp);

    // ── Bloque 21 — Coliseo cubierto (oscuro centro) ─────────────
    _b(canvas, w, h, 0.47, 0.47, 0.12, 0.07, const Color(0xFF1A2535), 'b21');
    // patio interior
    canvas.drawRect(Rect.fromLTWH(w*0.49, h*0.485, w*0.08, h*0.04),
        Paint()..color = const Color(0xFF0D180D));

    // ── Bloque 22 — Gimnasio ──────────────────────────────────────
    _b(canvas, w, h, 0.65, 0.48, 0.10, 0.07, const Color(0xFFD45A30), 'b22');

    // ── Bloque 1 — ITI Pascual Bravo (cian, con patio) ───────────
    _b(canvas, w, h, 0.12, 0.44, 0.12, 0.13, const Color(0xFF0E3A3A), 'b1');
    canvas.drawRect(Rect.fromLTWH(w*0.14, h*0.46, w*0.08, h*0.09),
        Paint()..color = const Color(0xFF0D180D));

    // ── Bloques oscuros sur (23-25) ───────────────────────────────
    _b(canvas, w, h, 0.45, 0.67, 0.12, 0.12, const Color(0xFF1A2535), 'b25');
    _b(canvas, w, h, 0.56, 0.69, 0.14, 0.13, const Color(0xFF1A2535), 'b24');
    _b(canvas, w, h, 0.70, 0.66, 0.09, 0.11, const Color(0xFF1A2535), 'b23');

    // ── Bloque 26 — Ciudadela PNG (naranja-L sur) ─────────────────
    _bL(canvas, w, h, 0.19, 0.80, 0.15, 0.09, const Color(0xFFD45A30), 'b26');

    // ── Brújula ───────────────────────────────────────────────────
    _brujula(canvas, Offset(w*0.12, h*0.93), w*0.04);
  }

  // Dibuja un bloque rectangular con borde de selección
  void _b(Canvas c, double w, double h,
      double rx, double ry, double rw, double rh,
      Color color, String id) {
    final isSel = selected == id;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w*rx, h*ry, w*rw, h*rh), Radius.circular(w*0.008));
    c.drawRRect(rect, Paint()..color = color);
    if (isSel) {
      c.drawRRect(rect, Paint()
        ..color = Colors.white.withOpacity(0.7 + 0.3 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
    }
  }

  // Bloque en forma de L
  void _bL(Canvas c, double w, double h,
      double rx, double ry, double rw, double rh,
      Color color, String id) {
    final isSel = selected == id;
    // Parte horizontal
    final p = Paint()..color = color;
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w*rx, h*ry, w*rw, h*(rh*0.5)), Radius.circular(w*0.006)), p);
    // Parte vertical (mitad del ancho)
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w*rx, h*ry, w*(rw*0.45), h*rh), Radius.circular(w*0.006)), p);
    if (isSel) {
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(w*rx, h*ry, w*rw, h*(rh*0.5)), Radius.circular(w*0.006)));
      c.drawPath(path, Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
    }
  }

  void _brujula(Canvas c, Offset center, double r) {
    c.drawCircle(center, r, Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 1);
    // N
    final north = Path()
      ..moveTo(center.dx, center.dy - r + 2)
      ..lineTo(center.dx - r*0.4, center.dy + r*0.3)
      ..lineTo(center.dx + r*0.4, center.dy + r*0.3)
      ..close();
    c.drawPath(north, Paint()..color = Colors.white.withOpacity(0.6));
    // S
    final south = Path()
      ..moveTo(center.dx, center.dy + r - 2)
      ..lineTo(center.dx - r*0.4, center.dy - r*0.3)
      ..lineTo(center.dx + r*0.4, center.dy - r*0.3)
      ..close();
    c.drawPath(south, Paint()..color = Colors.white.withOpacity(0.25));
    // Letra N
    final tp = TextPainter(
      text: TextSpan(text: 'N', style: TextStyle(
          color: Colors.white.withOpacity(0.7), fontSize: r*0.7,
          fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width/2, center.dy - r - tp.height - 1));
  }

  @override
  bool shouldRepaint(_CampusPainter old) =>
      old.selected != selected || old.pulse != pulse;
}
