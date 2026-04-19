import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'model_user.dart';
import 'api_client.dart';
import 'widget_campus_map.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}


// Categorías de gustos/hobbies predefinidas (estilo Tinder)
const Map<String, List<String>> _gustosCategorias = {
  '🎵 Música': [
    'Reggaetón', 'Pop', 'Rock', 'Electrónica', 'Hip-Hop', 'Salsa', 'Jazz',
    'Clásica', 'Metal', 'Indie', 'Vallenato', 'K-Pop',
  ],
  '🎮 Gaming': [
    'Videojuegos', 'eSports', 'RPG', 'FPS', 'Minecraft', 'FIFA', 'League of Legends',
    'Juegos de mesa', 'Ajedrez', 'Poker',
  ],
  '🏃 Deporte': [
    'Fútbol', 'Baloncesto', 'Natación', 'Ciclismo', 'Gimnasio', 'Crossfit',
    'Yoga', 'Running', 'Artes marciales', 'Tenis', 'Voleibol', 'Skateboard',
  ],
  '🎨 Arte & Creatividad': [
    'Dibujo', 'Pintura', 'Fotografía', 'Diseño gráfico', 'Moda', 'Cerámica',
    'Manualidades', 'Bordado', 'Escultura', 'Ilustración digital',
  ],
  '📚 Conocimiento': [
    'Lectura', 'Ciencia', 'Historia', 'Filosofía', 'Idiomas', 'Programación',
    'Emprendimiento', 'Economía', 'Psicología', 'Política',
  ],
  '🍕 Gastronomía': [
    'Cocinar', 'Repostería', 'Café', 'Comida saludable', 'Vegano',
    'Street food', 'Sushi', 'Parrilla', 'Cocteles',
  ],
  '✈️ Aventura': [
    'Senderismo', 'Viajes', 'Camping', 'Escalada', 'Surf', 'Buceo',
    'Parapente', 'Mochilero', 'Turismo cultural',
  ],
  '🎬 Entretenimiento': [
    'Cine', 'Series', 'Anime', 'Stand-up comedy', 'Teatro', 'Conciertos',
    'Podcasts', 'YouTube', 'Netflix', 'K-dramas',
  ],
  '🌿 Bienestar': [
    'Meditación', 'Mindfulness', 'Salud mental', 'Espiritualidad',
    'Voluntariado', 'Sostenibilidad', 'Naturaleza', 'Jardinería',
  ],
};

class _OnboardingScreenState extends State<OnboardingScreen> {
  // ── Navegación ─────────────────────────────────────────────────
  int    _paso    = 0;
  bool   _loading = false;
  String? _error;

  static const Map<String, int> _pasoAIndice = {
    'terminos':      0,
    'basico':        1,
    'intenciones':   2,
    'preferencias':  3,
    'personal':      4,
    'institucional': 5,
    'fotos':         6,
    'completo':      6,
  };

  // Paso 0 — T&C (un solo checkbox)
  bool _aceptoTc = false;

  // Paso 1 — Básico
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  DateTime? _fechaNac;
  // FIX #2: separamos sexo, género e identidad
  String _sexoBiologico = '';
  String _genero        = '';
  String _orientacion   = '';

  // Estado de sugerencias de identidad


  // Paso 2 — Intenciones
  final Set<String> _intenciones = {};

  // Paso 3 — Preferencias (solo pareja y/o amistad, condicionado a intenciones)
  final List<String> _interesadoEnPareja  = [];
  final List<String> _interesadoEnAmistad = [];

  // Paso 4 — Personal
  final _bioLargaCtrl = TextEditingController();
  final _bioCtrl      = TextEditingController();
  final List<String> _gustos = [];
  String _fuma       = 'no';
  String _bebe       = 'no';
  String _fiesta     = 'no';
  bool _animalesGustan = false;
  bool _tieneAnimales  = false;
  final _animalesCtrl     = TextEditingController();
  final _mascotaNombreCtrl = TextEditingController();
  final Set<String> _tiposMascota = {}; // perro, gato, ave, reptil, roedor, pez, otro

  // Paso 5 — Institucional (dinámico desde backend)
  List<Map<String, dynamic>> _facultades = [];   // [{id, nombre, programas:[]}]
  String? _facultadSelId;
  String? _facultadSelNombre;
  List<String> _programasFacultad = [];
  String? _programaSel;
  int _semestre       = 1;
  String _gustaCarrera       = 'esta_ok';
  String _trabajoPref        = 'ambos';
  bool   _buscaTesis         = false;
  final  _proyeccionCtrl     = TextEditingController();
  final  List<String> _habilidades  = [];
  final  List<String> _debilidades  = [];
  bool _cargandoFacultades = false;

  // Paso "Disponibilidad" — removemos radio de búsqueda, añadimos bloque campus
  // FIX #5: en vez de radio de búsqueda → bloque de la universidad
  String _bloqueUniversidad = '';
  bool   _disponibleAhora = false;
  final List<Map<String, String>> _horarioClases = [];
  static const List<String> _diasSemana = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];

  // FIX #5: bloques del campus Pascual Bravo (foto del mapa referenciada)
  // Paso 6 — Fotos
  final List<Map<String, dynamic>> _fotos = [];

  // FIX #9: pasos dinámicos según intenciones
  List<String> get _pasos {
    final base = ['Términos', 'Básico', 'Intenciones'];
    // Solo mostrar preferencias si hay pareja o amistad
    final tienePareja  = _intenciones.contains('pareja');
    final tieneAmistad = _intenciones.contains('amistad');
    if (tienePareja || tieneAmistad) base.add('Preferencias');
    base.addAll(['Sobre ti', 'Institución', 'Disponibilidad', 'Fotos']);
    return base;
  }

  // Índice real del paso teniendo en cuenta si Preferencias existe o no
  int _pasoReal(int visualIndex) {
    final tienePrefs = _intenciones.contains('pareja') || _intenciones.contains('amistad');
    if (!tienePrefs && visualIndex >= 3) return visualIndex + 1; // skip preferences paso interno
    return visualIndex;
  }

  @override
  void initState() {
    super.initState();
    _sincronizarPasoBackend();
    _cargarFacultades();
  }

  Future<void> _cargarFacultades() async {
    setState(() => _cargandoFacultades = true);
    try {
      final data = await ApiClient.get('/api/v1/academia/facultades/');
      if (data is List && mounted) {
        setState(() {
          _facultades = List<Map<String, dynamic>>.from(data);
          _cargandoFacultades = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoFacultades = false);
    }
  }

  void _onFacultadChanged(String? id) {
    if (id == null) return;
    final fac = _facultades.firstWhere((f) => f['id'].toString() == id,
        orElse: () => {});
    final programas = (fac['programas'] as List? ?? [])
        .map((p) => p['nombre'].toString())
        .toList();
    setState(() {
      _facultadSelId      = id;
      _facultadSelNombre  = fac['nombre']?.toString() ?? '';
      _programasFacultad  = programas;
      _programaSel        = null;
    });
  }

  void _checkCumpleanos(DateTime fechaNac) {
    final hoy   = DateTime.now();
    final cumple = DateTime(hoy.year, fechaNac.month, fechaNac.day);
    final diff  = cumple.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final diffFinal = diff < 0 ? diff + 365 : diff;
    if (diffFinal >= 0 && diffFinal <= 7) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final mensaje = diffFinal == 0
            ? '🎂 ¡Feliz cumpleaños! Hoy es tu día especial.'
            : '🎂 ¡Feliz cumpleaños anticipado! Tu cumple es en $diffFinal día${diffFinal == 1 ? '' : 's'}.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje, style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFFE91E8C),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16, right: 16, bottom: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      });
    }
  }

  Future<void> _sincronizarPasoBackend() async {
    try {
      final data = await ApiClient.get('/api/v1/onboarding/estado/');
      final pasoBackend = data['paso_actual'] ?? data['onboarding_paso'] ?? 'terminos';
      final indice = _pasoAIndice[pasoBackend] ?? 0;

      // El backend devuelve 'nombre' y 'apellido' por separado desde /auth/me/
      final me      = await ApiClient.get('/api/v1/auth/me/');
      final nombre  = (me['nombre']   ?? '').toString().trim();
      final apellido = (me['apellido'] ?? '').toString().trim();

      if (mounted) {
        setState(() {
          _paso = indice;
          _nombreCtrl.text   = nombre;
          _apellidoCtrl.text = apellido;
          if (indice == 6) _cargarFotosExistentes();
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarFotosExistentes() async {
    try {
      final data = await ApiClient.get('/api/v1/onboarding/fotos/lista/');
      if (mounted && data is List) {
        setState(() {
          _fotos.clear();
          for (final f in data) {
            _fotos.add({
              'id':           f['id'],
              'estado':       f['estado'] ?? 'pending',
              'url_medium':   f['url_medium'],
              'url_original': f['url_original'],
              'previewBytes': null,
            });
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _apellidoCtrl.dispose();
    _bioLargaCtrl.dispose(); _bioCtrl.dispose();
    _animalesCtrl.dispose();
    _mascotaNombreCtrl.dispose();
    _proyeccionCtrl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildPaso(),
          )),
          _buildBottomBar(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final pasos = _pasos;
    return Container(
      color: KoraColors.bgCard,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(children: [
        Row(children: [
          ShaderMask(
            shaderCallback: (b) => KoraGradients.mainGradient.createShader(b),
            child: Text('Paso ${_paso + 1} de ${pasos.length}',
              style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 13, color: Colors.white)),
          ),
          const Spacer(),
          Text(pasos[_paso],
            style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_paso + 1) / pasos.length,
            minHeight: 6,
            backgroundColor: KoraColors.divider,
            valueColor: const AlwaysStoppedAnimation(KoraColors.primary),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: KoraColors.bgCard,
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: KoraColors.pass.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KoraColors.pass.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: KoraColors.pass, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!,
                style: const TextStyle(color: KoraColors.pass, fontSize: 13))),
            ]),
          ),
        Row(children: [
          if (_paso > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() { _paso--; _error = null; }),
                child: const Text('Atrás'),
              ),
            ),
          if (_paso > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: KoraGradientButton(
              label: _paso == _pasos.length - 1 ? '¡Completar!' : 'Continuar',
              loading: _loading,
              // Paso de términos (0): inactivo hasta que acepte las políticas
              onPressed: (_paso == 0 && !_aceptoTc) ? null : _siguiente,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildPaso() {
    // FIX #9: pasos dinámicos según intenciones
    final tienePrefs = _intenciones.contains('pareja') || _intenciones.contains('amistad');
    return switch (_paso) {
      0 => _buildTerminos(),
      1 => _buildBasico(),
      2 => _buildIntenciones(),
      3 when tienePrefs => _buildPreferencias(),
      3 when !tienePrefs => _buildPersonal(),
      4 when tienePrefs => _buildPersonal(),
      4 when !tienePrefs => _buildInstitucional(),
      5 when tienePrefs => _buildInstitucional(),
      5 when !tienePrefs => _buildDisponibilidad(),
      6 when tienePrefs => _buildDisponibilidad(),
      6 when !tienePrefs => _buildFotos(),
      7 => _buildFotos(),
      _ => const SizedBox(),
    };
  }

  // ── PASO 0: Términos ─────────────────────────────────────────
  Widget _buildTerminos() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Términos y Condiciones',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 16),
      Container(
        height: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KoraColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KoraColors.divider),
        ),
        child: const SingleChildScrollView(child: Text(
          'TÉRMINOS Y CONDICIONES DE KORA\n\n'
          'Al usar Kora aceptas que:\n\n'
          '1. Eres mayor de 18 años y estudiante de la institución.\n\n'
          '2. La información que proporcionas es verídica.\n\n'
          '3. Usarás la plataforma de manera respetuosa.\n\n'
          '4. No compartirás contenido inapropiado.\n\n'
          '5. Kora puede suspender cuentas que violen estas normas.\n\n'
          'TRATAMIENTO DE DATOS PERSONALES:\n\n'
          'Tus datos se usan exclusivamente para el funcionamiento de la '
          'plataforma. No se venden a terceros. Puedes solicitar la eliminación '
          'de tu cuenta en cualquier momento.',
          style: TextStyle(color: KoraColors.textSecondary, height: 1.5),
        )),
      ),
      const SizedBox(height: 12),
      _checkTile(
        'He leído y acepto los Términos, Condiciones y el tratamiento de mis datos personales.',
        _aceptoTc,
        (v) => setState(() => _aceptoTc = v!),
      ),
    ],
  );

  Widget _checkTile(String label, bool value, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: value ? KoraColors.primary.withOpacity(0.05) : KoraColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? KoraColors.primary.withOpacity(0.3) : KoraColors.divider),
      ),
      child: CheckboxListTile(
        value: value, onChanged: onChanged,
        title: Text(label,
            style: const TextStyle(fontSize: 14, color: KoraColors.textPrimary)),
        activeColor: KoraColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  // ── PASO 1: Básico ────────────────────────────────────────────
  Widget _buildBasico() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Cuéntanos sobre ti',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 20),
      _field(_nombreCtrl, 'Nombre(s)', Icons.person_outline),
      const SizedBox(height: 12),
      _field(_apellidoCtrl, 'Apellidos', Icons.person_outline),
      const SizedBox(height: 12),
      _datePicker(),
      const SizedBox(height: 24),

      // ── Sexo biológico ──────────────────────────────────────────
      _identitySelector(
        titulo: 'Sexo biológico',
        valor: _sexoBiologico,
        placeholder: 'Selecciona una opción',
        opciones: const {
          'hombre':            ('Hombre',           '♂ Características físicas y biológicas masculinas.'),
          'mujer':             ('Mujer',             '♀ Características físicas y biológicas femeninas.'),
          'intersexual':       ('Intersexual',       'Características biológicas que no encajan en definiciones típicas de masculino/femenino.'),
          'prefiero_no_decir': ('Prefiero no decir', 'Tu privacidad es importante. Podemos continuar sin esta información.'),
        },
        onChanged: (v) => setState(() => _sexoBiologico = v),
        context: context,
      ),
      const SizedBox(height: 20),

      // ── Identidad de género ─────────────────────────────────────
      _identitySelector(
        titulo: 'Identidad de género',
        valor: _genero,
        placeholder: 'Selecciona una opción',
        opciones: const {
          'hombre_cis':        ('Hombre cisgénero',    'Te identificas como hombre y tu sexo asignado al nacer fue masculino.'),
          'hombre_trans':      ('Hombre trans',         'Te identificas como hombre y tu sexo asignado al nacer fue femenino.'),
          'mujer_cis':         ('Mujer cisgénero',      'Te identificas como mujer y tu sexo asignado al nacer fue femenino.'),
          'mujer_trans':       ('Mujer trans',           'Te identificas como mujer y tu sexo asignado al nacer fue masculino.'),
          'no_binario':        ('No binario',            'No te identificas exclusivamente como hombre ni como mujer.'),
          'género_fluido':     ('Género fluido',         'Tu identidad de género varía o cambia con el tiempo.'),
          'agénero':           ('Agénero',               'No te identificas con ningún género o sientes ausencia de género.'),
          'bigénero':          ('Bigénero',              'Te identificas con dos géneros, ya sea simultánea o alternativamente.'),
          'genderqueer':       ('Genderqueer',           'Te identificas fuera de las normas binarias de género.'),
          'transmasculino':    ('Transmasculino',        'Persona asignada femenina al nacer que se identifica en el espectro masculino.'),
          'transfemenino':     ('Transfemenino',         'Persona asignada masculina al nacer que se identifica en el espectro femenino.'),
          'pangénero':         ('Pangénero',             'Te identificas con todos los géneros o una combinación de ellos.'),
          'dos_espíritus':     ('Dos espíritus',         'Identidad espiritual y cultural de pueblos indígenas de Norteamérica.'),
          'otro':              ('Otro',                  'Tu identidad de género no está en esta lista.'),
          'hombre_intersex':   ('Hombre intersexual',   'Te identificas como hombre y naciste con características intersexuales.'),
          'mujer_intersex':    ('Mujer intersexual',    'Te identificas como mujer y naciste con características intersexuales.'),
          'prefiero_no_decir': ('Prefiero no decir',    'Tu privacidad es importante. Podemos continuar sin esta información.'),
        },
        onChanged: (v) => setState(() => _genero = v),
        context: context,
      ),
      const SizedBox(height: 20),

      // ── Orientación sexual ──────────────────────────────────────
      _identitySelector(
        titulo: 'Orientación sexual',
        valor: _orientacion,
        placeholder: 'Selecciona una opción',
        opciones: const {
          'heterosexual':      ('Heterosexual',      'Atracción hacia personas del género opuesto al tuyo.'),
          'gay':               ('Gay / Homosexual',   'Atracción hacia personas del mismo género.'),
          'lesbiana':          ('Lesbiana',           'Mujer con atracción hacia otras mujeres.'),
          'bisexual':          ('Bisexual',           'Atracción hacia personas de tu mismo género y de otros géneros.'),
          'pansexual':         ('Pansexual',          'Atracción hacia personas independientemente de su género.'),
          'asexual':           ('Asexual',            'Poca o ninguna atracción sexual hacia otras personas.'),
          'demisexual':        ('Demisexual',         'Atracción sexual solo después de formar un vínculo emocional fuerte.'),
          'queer':             ('Queer',              'Identidad fluida que no se limita a categorías fijas.'),
          'explorando':        ('Explorando',         'Aún estás descubriendo tu orientación sexual.'),
          'arromántico':       ('Arromántico',        'Poca o ninguna atracción romántica hacia otras personas.'),
          'omnisexual':        ('Omnisexual',         'Atracción hacia todos los géneros, siendo consciente de ellos.'),
          'otro':              ('Otro',               'Tu orientación sexual no está en esta lista.'),
          'prefiero_no_decir': ('Prefiero no decir',  'Tu privacidad es importante. Podemos continuar sin esta información.'),
        },
        onChanged: (v) => setState(() => _orientacion = v),
        context: context,
      ),
    ],
  );

  /// Selector de identidad: título + opciones con descripción inline + popup de sugerencia.
  /// Las opciones se muestran como lista custom (no DropdownButton) para poder incluir
  /// la descripción de la opción actualmente seleccionada debajo del selector.
  Widget _identitySelector({
    required String titulo,
    required String valor,
    required String placeholder,
    required Map<String, (String, String)> opciones, // value → (label, descripcion)
    required void Function(String) onChanged,
    required BuildContext context,
  }) {
    final labelActual = valor.isNotEmpty ? opciones[valor]?.$1 : null;
    final descActual  = valor.isNotEmpty ? opciones[valor]?.$2 : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(titulo),
      const SizedBox(height: 6),

      // ── Selector personalizado ──────────────────────────────────
      GestureDetector(
        onTap: () => _mostrarOpcionesIdentidad(
          context: context,
          titulo: titulo,
          opciones: opciones,
          valorActual: valor,
          onChanged: onChanged,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: KoraColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: valor.isNotEmpty
                  ? KoraColors.primary.withOpacity(0.4)
                  : KoraColors.divider,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                labelActual ?? placeholder,
                style: TextStyle(
                  fontSize: 15,
                  color: labelActual != null
                      ? KoraColors.textPrimary
                      : KoraColors.textHint,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: KoraColors.textSecondary),
          ]),
        ),
      ),

      // ── Descripción de la opción seleccionada ──────────────────
      if (descActual != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KoraColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: KoraColors.primary.withOpacity(0.12)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded,
                size: 13, color: KoraColors.primary.withOpacity(0.7)),
            const SizedBox(width: 8),
            Expanded(child: Text(descActual,
              style: const TextStyle(
                  fontSize: 12, color: KoraColors.textSecondary, height: 1.5))),
          ]),
        ),
      ],

      const SizedBox(height: 6),

      // ── Botón "No lo encuentro" → popup ────────────────────────
      GestureDetector(
        onTap: () => _mostrarPopupSugerencia(context, titulo),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.help_outline_rounded, size: 13, color: KoraColors.textHint),
          const SizedBox(width: 4),
          Text('No lo encuentro — sugerir al equipo',
            style: const TextStyle(
              fontSize: 12, color: KoraColors.textHint,
              decoration: TextDecoration.underline,
              decorationColor: KoraColors.textHint,
            )),
        ]),
      ),
    ]);
  }

  /// Bottom sheet con las opciones de identidad en formato lista.
  void _mostrarOpcionesIdentidad({
    required BuildContext context,
    required String titulo,
    required Map<String, (String, String)> opciones,
    required String valorActual,
    required void Function(String) onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: KoraColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: KoraColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(children: [
              Text(titulo,
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: KoraColors.textPrimary)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20,
                    color: KoraColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          const Divider(height: 1, color: KoraColors.divider),
          // Lista de opciones scrolleable
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: opciones.length,
              itemBuilder: (_, i) {
                final entry  = opciones.entries.elementAt(i);
                final isSelected = entry.key == valorActual;
                return InkWell(
                  onTap: () {
                    onChanged(entry.key);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? KoraColors.primary.withOpacity(0.08)
                          : Colors.transparent,
                      border: isSelected
                          ? Border(
                              left: BorderSide(
                                  color: KoraColors.primary, width: 3))
                          : null,
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.value.$1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? KoraColors.primary
                                    : KoraColors.textPrimary,
                              )),
                            const SizedBox(height: 2),
                            Text(entry.value.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: KoraColors.textSecondary,
                                height: 1.4,
                              )),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: KoraColors.primary),
                    ]),
                  ),
                );
              },
            ),
          ),
          // Botón sugerencia al pie del sheet
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _mostrarPopupSugerencia(context, titulo);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: KoraColors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KoraColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.help_outline_rounded,
                        size: 15, color: KoraColors.textSecondary),
                    const SizedBox(width: 8),
                    Text('No lo encuentro — sugerir al equipo',
                      style: const TextStyle(
                          fontSize: 13, color: KoraColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Popup de sugerencia de identidad.
  void _mostrarPopupSugerencia(BuildContext context, String categoria) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sugerir al equipo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                color: KoraColors.textPrimary)),
          Text('Categoría: $categoria',
            style: const TextStyle(fontSize: 12,
                color: KoraColors.textSecondary)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: KoraColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: '¿Cómo te identificas? Describe tu identidad...',
            hintStyle: const TextStyle(color: KoraColors.textHint, fontSize: 13),
            filled: true,
            fillColor: KoraColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: KoraColors.primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
              style: TextStyle(color: KoraColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: KoraColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final texto = ctrl.text.trim();
              if (texto.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.post('/api/v1/users/me/sugerencia/', body: {
                  'categoria':  categoria,
                  'sugerencia': texto,
                });
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(children: [
                      Text('💜 ¡Gracias! Tu sugerencia fue enviada al equipo.'),
                    ]),
                    backgroundColor: KoraColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(
                        top: 16, left: 16, right: 16, bottom: 0),
                  ),
                );
              }
            },
            child: const Text('Enviar',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }


  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: KoraColors.primary)),
            child: child!,
          ),
        );
        if (d != null) setState(() => _fechaNac = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KoraColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _fechaNac != null ? KoraColors.primary : KoraColors.divider,
            width: _fechaNac != null ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
            color: _fechaNac != null ? KoraColors.primary : KoraColors.textHint,
            size: 18),
          const SizedBox(width: 12),
          Text(
            _fechaNac == null ? 'Fecha de nacimiento'
                : '${_fechaNac!.day}/${_fechaNac!.month}/${_fechaNac!.year}',
            style: TextStyle(
              color: _fechaNac == null ? KoraColors.textHint : KoraColors.textPrimary,
              fontSize: 15),
          ),
        ]),
      ),
    );
  }

  // ── PASO 2: Intenciones — FIX #9 ─────────────────────────────
  Widget _buildIntenciones() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('¿Qué buscas?',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const Text('Puedes elegir más de una. Las secciones siguientes\nse adaptarán a tu selección.',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 24),
      _intentionCard('pareja',  '❤️', 'Pareja',
          'Conocer a alguien especial', const Color(0xFFFF4D8B)),
      const SizedBox(height: 12),
      _intentionCard('amistad', '🤝', 'Amistad',
          'Hacer nuevos amigos', const Color(0xFF6C63FF)),
      const SizedBox(height: 12),
      _intentionCard('estudio', '📚', 'Grupos de Estudio',
          'Compañeros de universidad', const Color(0xFF06B6D4)),
    ],
  );

  Widget _intentionCard(String key, String emoji, String title, String sub, Color color) {
    final sel = _intenciones.contains(key);
    return GestureDetector(
      onTap: () => setState(() {
        sel ? _intenciones.remove(key) : _intenciones.add(key);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.06) : KoraColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? color : KoraColors.divider,
            width: sel ? 2 : 1,
          ),
          boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.12),
              blurRadius: 12)] : [],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: sel ? color : KoraColors.textPrimary)),
            Text(sub, style: const TextStyle(color: KoraColors.textSecondary,
                fontSize: 13)),
          ])),
          if (sel)
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
        ]),
      ),
    );
  }

  // ── PASO 3: Preferencias — FIX #9 (solo si pareja o amistad) ─
  Widget _buildPreferencias() {
    const opciones = {
      'hombres':   ('👨', 'Hombres'),
      'mujeres':   ('👩', 'Mujeres'),
      'no_binario':('🧑', 'No binario'),
      'todos':     ('🌈', 'Todos'),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tus preferencias',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 6),
      Text('¿Con quién te interesa conectar?',
        style: TextStyle(fontSize: 14, color: KoraColors.textSecondary)),
      const SizedBox(height: 24),

      if (_intenciones.contains('pareja')) ...[
        // Card de pareja
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KoraColors.accent.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KoraColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('❤️', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              const Text('Pareja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: KoraColors.textPrimary)),
            ]),
            const SizedBox(height: 4),
            Text('Selecciona a quién te atrae',
              style: TextStyle(fontSize: 12, color: KoraColors.textHint)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: opciones.entries.map((e) {
              final sel = _interesadoEnPareja.contains(e.key);
              return GestureDetector(
                onTap: () => setState(() => sel
                    ? _interesadoEnPareja.remove(e.key)
                    : _interesadoEnPareja.add(e.key)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: sel ? KoraColors.accent.withOpacity(0.15) : KoraColors.bgElevated,
                    border: Border.all(
                      color: sel ? KoraColors.accent.withOpacity(0.7) : KoraColors.divider,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(e.value.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(e.value.$2,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? KoraColors.accent : KoraColors.textSecondary,
                      )),
                    if (sel) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: KoraColors.accent),
                    ],
                  ]),
                ),
              );
            }).toList()),
          ]),
        ),
        const SizedBox(height: 16),
      ],

      if (_intenciones.contains('amistad')) ...[
        // Card de amistad
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KoraColors.primary.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KoraColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🤝', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              const Text('Amistad',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: KoraColors.textPrimary)),
            ]),
            const SizedBox(height: 4),
            Text('¿Con quién quieres hacer amigos?',
              style: TextStyle(fontSize: 12, color: KoraColors.textHint)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: opciones.entries.map((e) {
              final sel = _interesadoEnAmistad.contains(e.key);
              return GestureDetector(
                onTap: () => setState(() => sel
                    ? _interesadoEnAmistad.remove(e.key)
                    : _interesadoEnAmistad.add(e.key)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: sel ? KoraColors.primary.withOpacity(0.15) : KoraColors.bgElevated,
                    border: Border.all(
                      color: sel ? KoraColors.primary.withOpacity(0.7) : KoraColors.divider,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(e.value.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(e.value.$2,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? KoraColors.primary : KoraColors.textSecondary,
                      )),
                    if (sel) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: KoraColors.primary),
                    ],
                  ]),
                ),
              );
            }).toList()),
          ]),
        ),
      ],
    ]);
  }

  // ── PASO 4: Personal — FIX #3 (contador bio) ─────────────────
  Widget _buildPersonal() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Sobre ti',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 16),

      // FIX #3: Bio corta con contador de caracteres visibles y palabras
      _bioCorta(),
      const SizedBox(height: 12),
      _field(_bioLargaCtrl, 'Cuéntanos más sobre ti...', Icons.article_outlined,
          maxLines: 4),
      const SizedBox(height: 16),
      _sectionLabel('Gustos / Hobbies (máx 15)'),
      const SizedBox(height: 4),
      Text('Toca para seleccionar o escribe el tuyo',
        style: TextStyle(fontSize: 11, color: KoraColors.textHint)),
      const SizedBox(height: 10),
      // Categorías predefinidas al estilo Tinder
      ..._gustosCategorias.entries.map((cat) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cat.key,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: KoraColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...cat.value.map((g) {
              final sel = _gustos.contains(g);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) { _gustos.remove(g); }
                  else if (_gustos.length < 15) { _gustos.add(g); }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: sel ? KoraColors.primary.withOpacity(0.15) : KoraColors.bgCard,
                    border: Border.all(
                      color: sel ? KoraColors.primary.withOpacity(0.6) : KoraColors.divider,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(g,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? KoraColors.primary : KoraColors.textSecondary,
                    )),
                ),
              );
            }),
          ]),
        ]),
      )),
      // Opción de texto libre
      if (_gustos.length < 15)
        GestureDetector(
          onTap: () async {
            final t = await _inputDialog('Agregar gusto personalizado');
            if (t != null && t.trim().isNotEmpty) setState(() => _gustos.add(t.trim()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KoraColors.primary.withOpacity(0.4),
                  style: BorderStyle.solid),
              color: KoraColors.bgCard,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_circle_outline, size: 14, color: KoraColors.primary),
              const SizedBox(width: 6),
              Text('Agregar otro (${_gustos.length}/15)',
                style: TextStyle(fontSize: 12, color: KoraColors.primary,
                    fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      // Chips de seleccionados (resumen)
      if (_gustos.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Seleccionados:', style: TextStyle(fontSize: 11,
            color: KoraColors.textHint, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: _gustos.map((g) => Chip(
          label: Text(g, style: const TextStyle(fontSize: 11,
              color: KoraColors.textPrimary)),
          onDeleted: () => setState(() => _gustos.remove(g)),
          deleteIconColor: KoraColors.textSecondary,
          backgroundColor: KoraColors.primary.withOpacity(0.10),
          side: BorderSide(color: KoraColors.primary.withOpacity(0.25)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList()),
      ],
      const SizedBox(height: 16),
      _habitoRow('¿Fumas?', ['no', 'ocasional', 'si'], _fuma,
          ['🚭 No', '🚬 Ocasional', '🚬 Sí'],
          (v) => setState(() => _fuma = v)),
      const SizedBox(height: 8),
      _habitoRow('¿Bebes?', ['no', 'ocasional', 'si'], _bebe,
          ['🧃 No', '🍻 Ocasional', '🍻 Sí'],
          (v) => setState(() => _bebe = v)),
      const SizedBox(height: 8),
      _habitoRow('¿Saldes de fiesta?', ['no', 'a_veces', 'si'], _fiesta,
          ['🏠 No', '🎉 A veces', '🎉 Sí'],
          (v) => setState(() => _fiesta = v)),
      const SizedBox(height: 12),
      // ── Animales ────────────────────────────────────────────
      _sectionLabel('Animales'),
      const SizedBox(height: 10),
      _yesNoTile('¿Te gustan los animales?', _animalesGustan,
          (v) => setState(() => _animalesGustan = v)),
      const SizedBox(height: 8),
      _yesNoTile('¿Tienes mascotas?', _tieneAnimales,
          (v) => setState(() => _tieneAnimales = v)),
      if (_tieneAnimales) ...[
        const SizedBox(height: 12),
        _sectionLabel('¿Qué tipo de mascota(s)?'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tipo in [
            ('🐶', 'perro', 'Perro'),
            ('🐱', 'gato', 'Gato'),
            ('🐦', 'ave', 'Ave'),
            ('🦎', 'reptil', 'Reptil'),
            ('🐹', 'roedor', 'Roedor'),
            ('🐟', 'pez', 'Pez'),
            ('🐾', 'otro', 'Otro'),
          ])
            GestureDetector(
              onTap: () => setState(() => _tiposMascota.contains(tipo.$2)
                  ? _tiposMascota.remove(tipo.$2)
                  : _tiposMascota.add(tipo.$2)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _tiposMascota.contains(tipo.$2)
                      ? KoraColors.primary.withOpacity(0.15)
                      : KoraColors.bgCard,
                  border: Border.all(
                    color: _tiposMascota.contains(tipo.$2)
                        ? KoraColors.primary.withOpacity(0.6)
                        : KoraColors.divider,
                    width: _tiposMascota.contains(tipo.$2) ? 1.5 : 1,
                  ),
                ),
                child: Text('${tipo.$1} ${tipo.$3}',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _tiposMascota.contains(tipo.$2)
                        ? KoraColors.primary : KoraColors.textSecondary,
                  )),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        _field(_mascotaNombreCtrl, 'Nombre de tu(s) mascota(s)', Icons.pets),
      ],
    ],
  );

  // FIX #3: bio corta con contador
  Widget _bioCorta() {
    const maxChars = 100;
    final texto = _bioCtrl.text;
    final chars  = texto.length;
    final faltan = maxChars - chars;
    final palabras = texto.trim().isEmpty ? 0 : texto.trim().split(RegExp(r'\s+')).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _bioCtrl,
        maxLength: maxChars,
        maxLines: 2,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Bio corta',
          hintText: 'Una frase que te represente...',
          prefixIcon: const Icon(Icons.edit_note, size: 18, color: KoraColors.textHint),
          counterText: '', // ocultamos el counter nativo
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: KoraColors.divider)),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        // Contador de caracteres restantes
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: faltan <= 10
                ? KoraColors.pass.withOpacity(0.12)
                : KoraColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$faltan caracteres restantes',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: faltan <= 10 ? KoraColors.pass : KoraColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        Text('· $palabras ${palabras == 1 ? 'palabra' : 'palabras'}',
          style: const TextStyle(fontSize: 11, color: KoraColors.textHint)),
      ]),
    ]);
  }

  Widget _habitoRow(String label, List<String> vals, String actual,
      List<String> labels, Function(String) onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600,
          fontSize: 13, color: KoraColors.textSecondary)),
      const SizedBox(height: 6),
      Row(children: List.generate(vals.length, (i) {
        final sel = actual == vals[i];
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < vals.length - 1 ? 6 : 0),
          child: GestureDetector(
            onTap: () => onChange(vals[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: sel ? KoraGradients.mainGradient : null,
                color: sel ? null : KoraColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : KoraColors.textSecondary)),
            ),
          ),
        ));
      })),
    ]);
  }

  Widget _yesNoTile(String label, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KoraColors.divider),
      ),
      child: Row(children: [
        Expanded(child: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: KoraColors.textPrimary))),
        const SizedBox(width: 12),
        Row(children: [
          GestureDetector(
            onTap: () => onChanged(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: value ? KoraColors.like.withOpacity(0.15) : KoraColors.bgElevated,
                border: Border.all(
                  color: value ? KoraColors.like.withOpacity(0.6) : KoraColors.divider,
                  width: value ? 1.5 : 1,
                ),
              ),
              child: Text('Sí',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: value ? KoraColors.like : KoraColors.textSecondary)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: !value ? KoraColors.accent.withOpacity(0.12) : KoraColors.bgElevated,
                border: Border.all(
                  color: !value ? KoraColors.accent.withOpacity(0.6) : KoraColors.divider,
                  width: !value ? 1.5 : 1,
                ),
              ),
              child: Text('No',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: !value ? KoraColors.accent : KoraColors.textSecondary)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _switchTile(String label, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 14, color: KoraColors.textPrimary))),
        Switch(value: value, onChanged: onChanged, activeColor: KoraColors.primary),
      ]),
    );
  }

  // ── PASO 5: Institucional — dropdowns dinámicos desde backend ──
  Widget _buildInstitucional() {
    final facultadItems = _facultades
        .map((f) => DropdownMenuItem<String>(
              value: f['id'].toString(),
              child: Text(f['nombre'].toString(), overflow: TextOverflow.ellipsis),
            ))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tu vida universitaria',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 4),
      Text('Cuéntanos sobre tu carrera para conectarte mejor.',
        style: TextStyle(fontSize: 14, color: KoraColors.textSecondary)),
      const SizedBox(height: 20),

      if (_cargandoFacultades)
        const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: KoraColors.primary, strokeWidth: 2),
        ))
      else ...[

        // ── Facultad ─────────────────────────────────────────────
        _sectionLabel('Facultad *'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _facultadSelId,
          decoration: const InputDecoration(
            hintText: 'Selecciona tu facultad',
            prefixIcon: Icon(Icons.school_outlined, size: 18, color: KoraColors.textHint),
          ),
          items: facultadItems,
          onChanged: _onFacultadChanged,
          isExpanded: true,
        ),
        const SizedBox(height: 16),

        // ── Programa/Carrera ──────────────────────────────────────
        _sectionLabel('Programa / Carrera *'),
        const SizedBox(height: 8),
        if (_facultadSelId == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: KoraColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KoraColors.divider),
            ),
            child: const Text('Selecciona primero una facultad',
              style: TextStyle(color: KoraColors.textHint, fontSize: 14)),
          )
        else
          DropdownButtonFormField<String>(
            value: _programaSel,
            decoration: const InputDecoration(
              hintText: 'Selecciona tu programa',
              prefixIcon: Icon(Icons.book_outlined, size: 18, color: KoraColors.textHint),
            ),
            items: _programasFacultad
                .map((p) => DropdownMenuItem(value: p,
                      child: Text(p, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _programaSel = v),
            isExpanded: true,
          ),
      ],

      const SizedBox(height: 20),

      // ── Semestre — selector visual de bloques ─────────────────
      _sectionLabel('Semestre'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: List.generate(12, (i) {
          final s = i + 1;
          final sel = _semestre == s;
          return GestureDetector(
            onTap: () => setState(() => _semestre = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46, height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: sel ? KoraGradients.mainGradient : null,
                color: sel ? null : KoraColors.bgElevated,
                border: Border.all(
                  color: sel ? Colors.transparent : KoraColors.divider,
                ),
                boxShadow: sel ? [BoxShadow(
                  color: KoraColors.primary.withOpacity(0.35),
                  blurRadius: 8, offset: const Offset(0, 3),
                )] : [],
              ),
              child: Center(
                child: Text('$s',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : KoraColors.textSecondary,
                  )),
              ),
            ),
          );
        }),
      ),

      const SizedBox(height: 20),

      // ── ¿Cómo te va con tu carrera? — tarjetas visuales ──────
      _sectionLabel('¿Cómo te va con tu carrera?'),
      const SizedBox(height: 8),
      ...{
        'la_amo':   ('❤️', 'La amo', 'Es mi pasión, me veo trabajando en esto toda la vida.', KoraColors.accent),
        'esta_ok':  ('👍', 'Está bien', 'Me gusta y encuentro sentido en lo que estudio.', KoraColors.accentGold),
        'no_mucho': ('😐', 'Más o menos', 'No me apasiona pero sigo adelante.', const Color(0xFF6B7280)),
        'la_odio':  ('😤', 'No es lo mío', 'Me equivoqué de carrera, pero aquí estoy.', KoraColors.primary),
      }.entries.map((e) {
        final sel = _gustaCarrera == e.key;
        return GestureDetector(
          onTap: () => setState(() => _gustaCarrera = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: sel ? e.value.$4.withOpacity(0.10) : KoraColors.bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? e.value.$4.withOpacity(0.55) : KoraColors.divider,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Text(e.value.$1, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.value.$2,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: sel ? e.value.$4 : KoraColors.textPrimary,
                  )),
                Text(e.value.$3,
                  style: const TextStyle(
                    fontSize: 12, color: KoraColors.textSecondary, height: 1.3)),
              ])),
              if (sel) Icon(Icons.check_circle_rounded, size: 18, color: e.value.$4),
            ]),
          ),
        );
      }),

      const SizedBox(height: 20),

      // ── ¿Por qué elegiste esta carrera? ──────────────────────
      _sectionLabel('¿Por qué elegiste esta carrera?'),
      const SizedBox(height: 8),
      TextField(
        controller: _proyeccionCtrl,
        maxLines: 3,
        maxLength: 300,
        style: const TextStyle(color: KoraColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Ej: Siempre me gustó la tecnología, quiero crear cosas...',
          hintStyle: TextStyle(color: KoraColors.textHint, fontSize: 13),
          filled: true,
          fillColor: KoraColors.bgElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: KoraColors.primary, width: 1.5),
          ),
          counterStyle: TextStyle(color: KoraColors.textHint, fontSize: 11),
        ),
      ),

      const SizedBox(height: 20),

      // ── Habilidades ───────────────────────────────────────────
      _sectionLabel('Mis habilidades (máx 10)'),
      const SizedBox(height: 4),
      Text('¿En qué eres bueno/a? Puede ser académico o personal.',
        style: TextStyle(fontSize: 11, color: KoraColors.textHint)),
      const SizedBox(height: 8),
      _chipsEditables(
        items: _habilidades,
        maxItems: 10,
        hint: 'Ej: programación, trabajo en equipo...',
        chipColor: KoraColors.like,
        onAdd: (v) => setState(() => _habilidades.add(v)),
        onRemove: (v) => setState(() => _habilidades.remove(v)),
      ),

      const SizedBox(height: 20),

      // ── Debilidades / Áreas de mejora ────────────────────────
      _sectionLabel('Áreas que quiero mejorar (máx 5)'),
      const SizedBox(height: 4),
      Text('Sé honesto/a. Todos tenemos algo en lo que podemos crecer.',
        style: TextStyle(fontSize: 11, color: KoraColors.textHint)),
      const SizedBox(height: 8),
      _chipsEditables(
        items: _debilidades,
        maxItems: 5,
        hint: 'Ej: matemáticas, gestión del tiempo...',
        chipColor: KoraColors.accentGold,
        onAdd: (v) => setState(() => _debilidades.add(v)),
        onRemove: (v) => setState(() => _debilidades.remove(v)),
      ),

      const SizedBox(height: 20),

      // ── Preferencia de trabajo ────────────────────────────────
      _sectionLabel('¿Cómo prefieres trabajar?'),
      const SizedBox(height: 8),
      _habitoRow('', ['grupo', 'ambos', 'individual'], _trabajoPref,
        ['👥 En grupo', '🔄 Me adapto', '🧑 Individual'],
        (v) => setState(() => _trabajoPref = v)),

      const SizedBox(height: 16),

      // ── ¿Buscas compañero de tesis? ──────────────────────────
      _yesNoTile('¿Buscas compañero de tesis o proyecto de grado?',
        _buscaTesis, (v) => setState(() => _buscaTesis = v)),
    ]);
  }

  /// Chips editables reutilizables para habilidades y debilidades.
  Widget _chipsEditables({
    required List<String> items,
    required int maxItems,
    required String hint,
    required Color chipColor,
    required void Function(String) onAdd,
    required void Function(String) onRemove,
  }) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...items.map((item) => Chip(
        label: Text(item, style: const TextStyle(fontSize: 12, color: KoraColors.textPrimary)),
        deleteIcon: const Icon(Icons.close, size: 14, color: KoraColors.textSecondary),
        onDeleted: () => onRemove(item),
        backgroundColor: chipColor.withOpacity(0.12),
        side: BorderSide(color: chipColor.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      )),
      if (items.length < maxItems)
        GestureDetector(
          onTap: () async {
            final t = await _inputDialog(hint);
            if (t != null && t.trim().isNotEmpty) onAdd(t.trim());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipColor.withOpacity(0.4)),
              color: KoraColors.bgCard,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_circle_outline, size: 14, color: chipColor),
              const SizedBox(width: 6),
              Text('Agregar (${items.length}/$maxItems)',
                style: TextStyle(fontSize: 12, color: chipColor,
                    fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
    ]);
  }

  // ── PASO 6: Disponibilidad — Mapa interactivo del campus ────────
  Widget _buildDisponibilidad() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Disponibilidad',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('¿Dónde sueles estar en el Pascual Bravo?',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 20),

      // ── Mapa interactivo del campus ───────────────────────────
      _sectionLabel('Selecciona tu bloque habitual'),
      const SizedBox(height: 4),
      Text('Toca un bloque en el mapa para seleccionarlo.',
        style: TextStyle(color: KoraColors.textHint, fontSize: 12)),
      const SizedBox(height: 12),
      CampusMapWidget(
        bloqueSeleccionado: _bloqueUniversidad,
        onBloqueSelected: (b) => setState(() => _bloqueUniversidad = b),
      ),
      const SizedBox(height: 8),
      if (_bloqueUniversidad.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: KoraGradients.mainGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(_bloqueNombreAmigable(_bloqueUniversidad),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),

      const SizedBox(height: 20),
      // ── Disponible ahora ───────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _disponibleAhora
              ? KoraColors.like.withOpacity(0.08) : KoraColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _disponibleAhora
                ? KoraColors.like.withOpacity(0.4) : KoraColors.divider),
        ),
        child: Row(children: [
          if (_disponibleAhora)
            Container(
              width: 8, height: 8, margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                color: KoraColors.like, shape: BoxShape.circle),
            ),
          Expanded(child: Text(
            _disponibleAhora ? 'Estoy disponible ahora' : '¿Disponible ahora?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: _disponibleAhora ? KoraColors.like : KoraColors.textPrimary))),
          Switch(
            value: _disponibleAhora,
            onChanged: (v) => setState(() => _disponibleAhora = v),
            activeColor: KoraColors.like),
        ]),
      ),

      const SizedBox(height: 28),
      _sectionLabel('Horario de clases *'),
      const SizedBox(height: 6),
      Text('Agrega al menos un bloque de clase. Kora activará "En clases" automáticamente durante esos horarios.',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),

      ..._horarioClases.asMap().entries.map((entry) {
        final i = entry.key;
        final bloque = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KoraColors.divider),
          ),
          child: Row(children: [
            const Icon(Icons.schedule, size: 16, color: KoraColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${bloque['dia']}  ${bloque['inicio']} – ${bloque['fin']}  · ${bloque['materia']}',
              style: const TextStyle(fontSize: 13, color: KoraColors.textPrimary),
            )),
            GestureDetector(
              onTap: () => setState(() => _horarioClases.removeAt(i)),
              child: const Icon(Icons.close, size: 16, color: KoraColors.textHint),
            ),
          ]),
        );
      }),

      const SizedBox(height: 8),
      GestureDetector(
        onTap: _agregarBloqueHorario,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: KoraColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KoraColors.primary.withOpacity(0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline, size: 18, color: KoraColors.primary),
            const SizedBox(width: 6),
            Text('Agregar bloque', style: TextStyle(
              color: KoraColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    ]);
  }

  String _bloqueNombreAmigable(String id) {
    // Nombres oficiales del campus (pascualbravo.edu.co/acerca-del-pascual/campus-universitario/)
    const nombres = {
      'b1':  'ITI Pascual Bravo',      'b2':  'Académico',
      'b3':  'Complejo Acuático',       'b4':  'Lab. LIDA (Automotriz)',
      'b5':  'Cientic',                 'b6':  'Académico',
      'b7':  'Bienestar',               'b8':  'Parque Tech',
      'b9':  'Lab. Dibujo / CAD',       'b10': 'Procesos Eléctricos',
      'b11': 'Taller Automotriz',       'b12': 'C.I. Energía Eléctrica',
      'b13': 'Escuela P. Diseño',       'b14': 'Lab. Textil',
      'b15': 'Lab. DIPMA',              'b16': 'Imprenta / Logística',
      'b17': 'CIDES — Soldadura',       'b18': 'Taller MEC',
      'b19': 'C.I. Materialografía',    'b20': 'Cancha Sintética',
      'b21': 'Coliseo Cubierto',        'b22': 'Gimnasio',
      'b23': 'Teatro La Convención',    'b24': 'Biblioteca',
      'b25': 'Administrativo',          'b26': 'Ciudadela Pedro Nel Gómez',
      'b27': 'Zona de Comidas',
    };
    return nombres[id] ?? id;
  }


  // FIX #6: materia es obligatoria en el diálogo
  Future<void> _agregarBloqueHorario() async {
    String dia      = _diasSemana[0];
    TimeOfDay inicio = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay fin    = const TimeOfDay(hour: 10, minute: 0);
    String materia  = '';
    String? errorMateria;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: KoraColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Agregar bloque de clase',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: dia,
              decoration: InputDecoration(
                labelText: 'Día',
                filled: true, fillColor: KoraColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              dropdownColor: KoraColors.bgCard,
              items: _diasSemana.map((d) =>
                DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setS(() => dia = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_rounded, size: 18),
              title: Text('Inicio: ${inicio.format(ctx)}',
                style: const TextStyle(fontSize: 14)),
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: inicio);
                if (t != null) setS(() => inicio = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop_rounded, size: 18),
              title: Text('Fin: ${fin.format(ctx)}',
                style: const TextStyle(fontSize: 14)),
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: fin);
                if (t != null) setS(() => fin = t);
              },
            ),
            const SizedBox(height: 4),
            // FIX #6: materia obligatoria
            TextField(
              decoration: InputDecoration(
                labelText: 'Materia *',
                errorText: errorMateria,
                filled: true, fillColor: KoraColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) { materia = v; setS(() => errorMateria = null); },
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                style: TextStyle(color: KoraColors.textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: KoraColors.primary),
              onPressed: () {
                if (materia.trim().isEmpty) {
                  setS(() => errorMateria = 'La materia es obligatoria');
                  return;
                }
                final fmt = (TimeOfDay t) =>
                    '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
                setState(() => _horarioClases.add({
                  'dia':     dia.toLowerCase(),
                  'inicio':  fmt(inicio),
                  'fin':     fmt(fin),
                  'materia': materia.trim(),
                }));
                Navigator.pop(ctx);
              },
              child: const Text('Agregar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── PASO 7: Fotos — FIX #8 (validación sexo) ─────────────────
  Widget _buildFotos() {
    final aprobadas = _fotos.where((f) => f['estado'] == 'approved').length;
    final pendientes = _fotos.where((f) => f['estado'] == 'pending').length;
    final rechazadas = _fotos.where((f) => f['estado'] == 'rejected').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tus fotos',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 4),
      RichText(text: TextSpan(children: [
        TextSpan(text: '$aprobadas/2 fotos mínimas · máximo 5',
          style: TextStyle(
            color: aprobadas >= 2 ? KoraColors.like : KoraColors.superlike,
            fontWeight: FontWeight.w500, fontSize: 14)),
        if (pendientes > 0)
          TextSpan(text: ' · $pendientes procesando...',
            style: const TextStyle(color: KoraColors.textHint, fontSize: 13)),
      ])),
      const SizedBox(height: 16),

      // FIX #8: aviso de validación según sexo
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KoraColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KoraColors.primary.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.shield_outlined, color: KoraColors.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Validación automática activa',
              style: TextStyle(color: KoraColors.primary, fontSize: 12,
                  fontWeight: FontWeight.w700),
            )),
          ]),
          const SizedBox(height: 6),
          Text(
            _sexoBiologico == 'hombre'
              ? 'Tu foto debe mostrarte a ti (hombre). '
                'Imágenes sin una persona visible serán rechazadas automáticamente.'
              : _sexoBiologico == 'mujer'
              ? 'Tu foto debe mostrarte a ti. '
                'El sistema verificará que el contenido sea apropiado.'
              : 'Tu foto debe mostrarte a ti. '
                'El sistema verificará que el contenido sea apropiado.',
            style: const TextStyle(color: KoraColors.textSecondary,
                fontSize: 11, height: 1.5),
          ),
          if (rechazadas > 0) ...[
            const SizedBox(height: 6),
            Text('$rechazadas foto${rechazadas > 1 ? 's' : ''} rechazada${rechazadas > 1 ? 's' : ''} — '
              'no cumplieron los requisitos de validación.',
              style: TextStyle(color: KoraColors.pass, fontSize: 11,
                  fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: _fotos.length < 5 ? _fotos.length + 1 : _fotos.length,
        itemBuilder: (ctx, i) {
          if (i == _fotos.length && _fotos.length < 5) {
            return GestureDetector(
              onTap: _loading ? null : _subirFoto,
              child: Container(
                decoration: BoxDecoration(
                  color: KoraColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: KoraColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(
                        color: KoraColors.primary, strokeWidth: 2))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate,
                          size: 32, color: KoraColors.primary.withOpacity(0.7)),
                        const SizedBox(height: 4),
                        const Text('Agregar', style: TextStyle(
                          color: KoraColors.primary, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                      ]),
              ),
            );
          }

          final foto     = _fotos[i];
          final estado   = foto['estado'] as String;
          final previewBytes = foto['previewBytes'] as Uint8List?;
          final urlMedium    = foto['url_medium'] as String?;

          return Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildFotoPreview(previewBytes, urlMedium, estado),
            ),
            if (estado == 'pending')
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white)),
                    const SizedBox(width: 5),
                    const Text('Validando', style: TextStyle(
                        color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.w500)),
                  ]),
                )),
            if (estado == 'approved')
              Positioned(bottom: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: KoraColors.like, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                )),
            if (estado == 'rejected')
              Positioned.fill(child: Container(
                decoration: BoxDecoration(
                  color: KoraColors.pass.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.block, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  const Text('Rechazada', style: TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w700)),
                ]),
              )),
            Positioned(top: 4, right: 4,
              child: GestureDetector(
                onTap: () => _eliminarFoto(i, foto['id']),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              )),
            if (i == 0 && estado != 'rejected')
              Positioned(top: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: KoraGradients.mainGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Principal',
                    style: TextStyle(color: Colors.white, fontSize: 8,
                        fontWeight: FontWeight.w700)),
                )),
          ]);
        },
      ),
    ]);
  }

  Widget _buildFotoPreview(Uint8List? bytes, String? urlMedium, String estado) {
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
    if (urlMedium != null && urlMedium.isNotEmpty) {
      return Image.network(
        '${ApiClient.baseUrl}$urlMedium',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fotoPlaceholder(estado),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(color: KoraColors.bg,
            child: const Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: KoraColors.primary)));
        },
      );
    }
    return _fotoPlaceholder(estado);
  }

  Widget _fotoPlaceholder(String estado) {
    return Container(
      color: KoraColors.bg,
      child: Icon(
        estado == 'pending' ? Icons.hourglass_top : Icons.broken_image_outlined,
        color: estado == 'pending' ? KoraColors.superlike : KoraColors.textHint,
        size: 28,
      ),
    );
  }

  // ── Acciones fotos ────────────────────────────────────────────
  Future<void> _subirFoto() async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(source: ImageSource.gallery,
        imageQuality: 85, maxWidth: 1200);
    if (img == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await img.readAsBytes();
      final fotoLocal = {
        'id':           null,
        'estado':       'uploading',
        'previewBytes': bytes,
        'url_medium':   null,
      };
      setState(() { _fotos.add(fotoLocal); _loading = false; });

      // FIX #8: pasar sexo biológico al backend para validación correcta
      dynamic fileArg = kIsWeb ? bytes : img.path;
      final data = await ApiClient.postMultipart(
        '/api/v1/onboarding/fotos/', fileArg,
        fields: {
          'es_principal':   _fotos.length == 1 ? 'true' : 'false',
          'sexo_biologico': _sexoBiologico,   // ← para que el worker valide correctamente
        },
      );

      final idx = _fotos.indexOf(fotoLocal);
      if (idx >= 0 && mounted) {
        setState(() {
          _fotos[idx] = {
            'id':           data['id'],
            'estado':       data['estado'] ?? 'pending',
            'previewBytes': bytes,
            'url_medium':   data['url_medium'],
          };
        });
        _pollFotoEstado(data['id'], idx);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _fotos.removeWhere((f) => f['estado'] == 'uploading');
        _error = e.message;
      });
    } catch (e) {
      if (mounted) setState(() {
        _fotos.removeWhere((f) => f['estado'] == 'uploading');
        _error = 'Error al subir la foto';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pollFotoEstado(int fotoId, int idx) async {
    // Máximo 20 intentos × 3 segundos = 60 segundos de espera.
    // Si el worker no responde en ese tiempo, eliminamos la foto
    // y mostramos un mensaje de error claro al usuario.
    const maxIntentos   = 20;
    const intervalSeg   = 3;

    for (int i = 0; i < maxIntentos; i++) {
      await Future.delayed(const Duration(seconds: intervalSeg));
      if (!mounted) return;

      try {
        final fotas = await ApiClient.get('/api/v1/onboarding/fotos/lista/');
        if (fotas is List) {
          final fotoData = fotas.firstWhere(
              (f) => f['id'] == fotoId, orElse: () => null);
          if (fotoData != null && mounted) {
            final nuevoEstado = fotoData['estado'] as String? ?? 'pending';
            setState(() {
              if (idx < _fotos.length) {
                _fotos[idx] = {
                  ..._fotos[idx],
                  'estado':     nuevoEstado,
                  'url_medium': fotoData['url_medium'],
                };
              }
            });
            // Resuelta (approved o rejected) → salir del polling
            if (nuevoEstado != 'pending') return;
          }
        }
      } catch (_) {}
    }

    // ── Timeout: el worker no respondió en ${maxIntentos * intervalSeg}s ──
    if (!mounted) return;

    // Eliminar la foto del servidor silenciosamente
    try {
      await ApiClient.delete('/api/v1/onboarding/fotos/$fotoId/');
    } catch (_) {}

    // Eliminar de la lista local y mostrar mensaje
    setState(() {
      if (idx < _fotos.length) _fotos.removeAt(idx);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.timer_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'La validación tardó demasiado y la foto fue eliminada. '
                'Intenta con una imagen más clara.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ]),
          backgroundColor: KoraColors.accent,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _eliminarFoto(int idx, int? fotoId) async {
    if (fotoId != null) {
      try { await ApiClient.delete('/api/v1/onboarding/fotos/$fotoId/'); } catch (_) {}
    }
    if (mounted) setState(() { if (idx < _fotos.length) _fotos.removeAt(idx); });
  }

  // ── Navegación ────────────────────────────────────────────────
  Future<void> _siguiente() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await _guardarPaso();
      if (!mounted) return;
      if (ok) {
        if (_paso < _pasos.length - 1) {
          setState(() => _paso++);
          if (_paso == _pasos.length - 1) _cargarFotosExistentes();
        } else {
          await _completar();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _guardarPaso() async {
    try {
      // Determinar qué paso lógico corresponde según la pantalla visual actual
      final tienePrefs = _intenciones.contains('pareja') || _intenciones.contains('amistad');

      // Mapeo visual → lógico
      int logicoPaso = _paso;
      if (!tienePrefs && _paso >= 3) logicoPaso = _paso + 1; // skip preferences

      switch (logicoPaso) {
        case 0:
          if (!_aceptoTc) {
            setState(() => _error = 'Debes aceptar los términos para continuar.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/terminos/',
              body: {'acepto_terminos': true, 'acepto_datos': true}); // backend sigue recibiendo ambos

        case 1:
          if (_nombreCtrl.text.trim().isEmpty || _apellidoCtrl.text.trim().isEmpty) {
            setState(() => _error = 'Nombre y apellido son obligatorios.');
            return false;
          }
          if (_fechaNac == null) {
            setState(() => _error = 'Selecciona tu fecha de nacimiento.');
            return false;
          }
          if (_sexoBiologico.isEmpty) {
            setState(() => _error = 'Selecciona tu sexo biológico para continuar.');
            return false;
          }
          if (_genero.isEmpty) {
            setState(() => _error = 'Selecciona tu identidad de género para continuar.');
            return false;
          }
          if (_orientacion.isEmpty) {
            setState(() => _error = 'Selecciona tu orientación sexual para continuar.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/basico/', body: {
            'nombre':            _nombreCtrl.text.trim(),
            'apellido':          _apellidoCtrl.text.trim(),
            'fecha_nacimiento':  '${_fechaNac!.year}-'
                '${_fechaNac!.month.toString().padLeft(2,'0')}-'
                '${_fechaNac!.day.toString().padLeft(2,'0')}',
            'genero':            _genero,
            'sexo_biologico':    _sexoBiologico,
            'orientacion_sexual': _orientacion,
          });
          _checkCumpleanos(_fechaNac!);

        case 2:
          if (_intenciones.isEmpty) {
            setState(() => _error = 'Selecciona al menos una intención.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/intenciones/',
              body: {'intenciones': _intenciones.toList()});

        case 3: // preferencias (solo si tiene pareja o amistad)
          await ApiClient.post('/api/v1/onboarding/preferencias/', body: {
            'orientacion_sexual':    _orientacion,
            'interesado_en_pareja':  _interesadoEnPareja,
            'interesado_en_amistad': _interesadoEnAmistad,
          });

        case 4: // personal
          // Validar mascotas antes de enviar
          if (_tieneAnimales && _tiposMascota.isEmpty && _mascotaNombreCtrl.text.trim().isEmpty) {
            setState(() => _error = 'Indica qué tipo de mascota tienes o su nombre.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/personal/', body: {
            'bio_corta':       _bioCtrl.text,
            'bio_larga':       _bioLargaCtrl.text,
            'gustos':          _gustos,
            'fuma':            _fuma,
            'bebe':            _bebe,
            'sale_fiesta':     _fiesta,
            'animales_gustan': _animalesGustan,
            'tiene_animales':  _tieneAnimales,
            // cuales_animales: construido desde tipos + nombre para compatibilidad con el backend
            'cuales_animales': _tieneAnimales
                ? [
                    if (_tiposMascota.isNotEmpty) _tiposMascota.join(', '),
                    if (_mascotaNombreCtrl.text.trim().isNotEmpty)
                      _mascotaNombreCtrl.text.trim(),
                  ].join(' — ')
                : '',
            'tipos_mascota':   _tiposMascota.toList(),
            'mascota_nombre':  _mascotaNombreCtrl.text.trim(),
          });

        case 5: // institucional
          if (_facultadSelNombre == null || _programaSel == null) {
            setState(() => _error = 'Selecciona tu facultad y programa.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/institucional/', body: {
            'facultad':      _facultadSelNombre!,
            'carrera':       _programaSel!,
            'semestre':      _semestre,
            'gusta_carrera':       _gustaCarrera,
            'proyeccion':          _proyeccionCtrl.text.trim(),
            'habilidades':         _habilidades,
            'debilidades':         _debilidades,
            'trabajo_preferencia': _trabajoPref,
            'busca_tesis':         _buscaTesis,
          });

        case 6: // disponibilidad
          if (_horarioClases.isEmpty) {
            setState(() => _error = 'Agrega al menos un bloque de clase para continuar.');
            return false;
          }
          await ApiClient.patch('/api/v1/users/me/profile/', body: {
            'campus_zona':      _bloqueUniversidad.isNotEmpty
                                  ? _bloqueUniversidad : 'general',
            'disponible_ahora': _disponibleAhora,
            'horario_clases':   _horarioClases,
          });
      }
      return true;
    } on ApiException catch (e) {
      final msg = e.message;
      if (msg.contains('Paso incorrecto') || msg.contains('paso_actual')) {
        final pasoActual = _extraerPasoError(msg);
        if (pasoActual != null) {
          final indice = _pasoAIndice[pasoActual] ?? _paso;
          setState(() { _error = null; _paso = indice; });
          return true;
        }
      }
      setState(() => _error = msg);
      return false;
    }
  }

  String? _extraerPasoError(String mensaje) {
    for (final key in _pasoAIndice.keys) {
      if (mensaje.contains(key)) return key;
    }
    return null;
  }

  Future<void> _completar() async {
    final aprobadas = _fotos.where((f) => f['estado'] == 'approved').length;
    final pendientes = _fotos.where((f) => f['estado'] == 'pending').length;

    if (aprobadas < 2) {
      if (pendientes > 0) {
        setState(() => _error =
          'Tus fotos ($pendientes) aún están siendo validadas. '
          'Espera un momento y vuelve a intentarlo.');
      } else {
        setState(() => _error =
          'Necesitas al menos 2 fotos aprobadas para completar tu perfil.');
      }
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient.post('/api/v1/onboarding/completar/');
      final userData = await ApiClient.get('/api/v1/auth/me/');
      if (mounted) {
        context.read<AuthProvider>().onboardingCompleted(UserModel.fromApi(userData));
      }
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    }
  }

  // ── Helpers UI ────────────────────────────────────────────────
  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, int? maxLength}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: KoraColors.textHint),
        counterText: maxLength != null ? null : '',
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
        color: KoraColors.textPrimary));

  Widget _dropdown<T>({
    required String label, required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _multiChips(List<String> opciones, List<String> seleccionados,
      {Map<String, String>? labels}) {
    return Wrap(spacing: 8, runSpacing: 8, children: opciones.map((o) {
      final sel   = seleccionados.contains(o);
      final label = labels?[o] ?? o;
      return GestureDetector(
        onTap: () => setState(() {
          sel ? seleccionados.remove(o) : seleccionados.add(o);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: sel ? KoraGradients.mainGradient : null,
            color: sel ? null : KoraColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel ? Colors.transparent : KoraColors.divider),
          ),
          child: Text(label, style: TextStyle(
            color: sel ? Colors.white : KoraColors.textSecondary,
            fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
    }).toList());
  }

  Future<String?> _inputDialog(String title) async {
    String val = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          onChanged: (v) => val = v,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe aquí...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, val),
            child: const Text('Agregar')),
        ],
      ),
    );
  }
}
