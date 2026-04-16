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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // ── Navegación ─────────────────────────────────────────────────
  int    _paso    = 0;
  bool   _loading = false;
  String? _error;

  // Mapa de paso backend → índice local
  static const Map<String, int> _pasoAIndice = {
    'terminos':      0,
    'basico':        1,
    'intenciones':   2,
    'preferencias':  3,
    'personal':      4,
    'institucional': 5,
    'fotos':         7,
    'completo':      7,
  };

  // Paso 0 — T&C
  bool _aceptoTc    = false;
  bool _aceptoDatos = false;

  // Paso 1 — Básico
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  DateTime? _fechaNac;
  String _genero = 'masculino';

  // Paso 2 — Intenciones
  final Set<String> _intenciones = {};

  // Paso 3 — Preferencias
  String _orientacion = 'prefiero_no_decir';
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
  final _animalesCtrl  = TextEditingController();

  // Paso 5 — Institucional
  final _facultadCtrl = TextEditingController();
  final _carreraCtrl  = TextEditingController();
  int _semestre       = 1;
  String _gustaCarrera = 'esta_ok';

  // Paso 6 — Disponibilidad
  String _campusZona     = 'general';
  int    _rangoDistancia = 5;
  bool   _disponibleAhora = false;

  // Paso 7 — Fotos
  // Cada item: { 'id': int?, 'estado': String, 'previewBytes': Uint8List?, 'url_medium': String? }
  final List<Map<String, dynamic>> _fotos = [];

  static const List<String> _pasos = [
    'Términos', 'Básico', 'Intenciones', 'Preferencias',
    'Sobre ti', 'Institución', 'Disponibilidad', 'Fotos'
  ];

  @override
  void initState() {
    super.initState();
    _sincronizarPasoBackend();
  }

  /// Sincroniza el paso real del backend para evitar "Paso incorrecto"
  Future<void> _sincronizarPasoBackend() async {
    try {
      final data = await ApiClient.get('/api/v1/onboarding/estado/');
      final pasoBackend = data['paso_actual'] ?? data['onboarding_paso'] ?? 'terminos';
      final indice = _pasoAIndice[pasoBackend] ?? 0;

      // Pre-llenar nombre desde el usuario autenticado
      final me = await ApiClient.get('/api/v1/auth/me/');
      final nombreCompleto = (me['nombre'] ?? '') as String;
      final partes = nombreCompleto.trim().split(' ');
      final mitad  = (partes.length / 2).ceil();

      if (mounted) {
        setState(() {
          _paso = indice;
          if (partes.length >= 2) {
            _nombreCtrl.text   = partes.take(mitad).join(' ');
            _apellidoCtrl.text = partes.skip(mitad).join(' ');
          } else {
            _nombreCtrl.text = nombreCompleto;
          }
          // Si ya está en fotos, cargar fotos existentes
          if (indice == 7) _cargarFotosExistentes();
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
    _animalesCtrl.dispose(); _facultadCtrl.dispose(); _carreraCtrl.dispose();
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
    return Container(
      color: KoraColors.bgCard,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(children: [
        Row(children: [
          ShaderMask(
            shaderCallback: (b) => KoraGradients.mainGradient.createShader(b),
            child: Text('Paso ${_paso + 1} de ${_pasos.length}',
              style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 13, color: Colors.white)),
          ),
          const Spacer(),
          Text(_pasos[_paso],
            style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_paso + 1) / _pasos.length,
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
                // El botón Atrás siempre funciona, independiente de _loading
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
              onPressed: _siguiente,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildPaso() {
    return switch (_paso) {
      0 => _buildTerminos(),
      1 => _buildBasico(),
      2 => _buildIntenciones(),
      3 => _buildPreferencias(),
      4 => _buildPersonal(),
      5 => _buildInstitucional(),
      6 => _buildDisponibilidad(),
      7 => _buildFotos(),
      _ => const SizedBox(),
    };
  }

  // ── PASO 0: Términos ──────────────────────────────────────────
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
      _checkTile('Acepto los términos y condiciones', _aceptoTc,
          (v) => setState(() => _aceptoTc = v!)),
      _checkTile('Acepto el tratamiento de mis datos personales', _aceptoDatos,
          (v) => setState(() => _aceptoDatos = v!)),
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
      const SizedBox(height: 12),
      _dropdown<String>(
        label: 'Género', value: _genero,
        items: const [
          DropdownMenuItem(value: 'masculino',        child: Text('Masculino')),
          DropdownMenuItem(value: 'femenino',         child: Text('Femenino')),
          DropdownMenuItem(value: 'no_binario',       child: Text('No binario')),
          DropdownMenuItem(value: 'otro',             child: Text('Otro')),
          DropdownMenuItem(value: 'prefiero_no_decir',child: Text('Prefiero no decir')),
        ],
        onChanged: (v) => setState(() => _genero = v!),
      ),
    ],
  );

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

  // ── PASO 2: Intenciones ───────────────────────────────────────
  Widget _buildIntenciones() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('¿Qué buscas?',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const Text('Puedes elegir más de una',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
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

  // ── PASO 3: Preferencias ──────────────────────────────────────
  Widget _buildPreferencias() {
    final soloEstudio = _intenciones.length == 1 && _intenciones.contains('estudio');
    if (soloEstudio) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: KoraGradients.subtleGradient,
              shape: BoxShape.circle,
            ),
            child: const Text('📚', style: TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 20),
          const Text('Solo buscas grupos de estudio',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: KoraColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('No necesitamos información adicional para este modo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KoraColors.textSecondary)),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tus preferencias',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 20),
      if (_intenciones.contains('pareja')) ...[
        _sectionLabel('Orientación sexual'),
        const SizedBox(height: 8),
        _dropdown<String>(
          label: 'Orientación', value: _orientacion,
          items: const [
            DropdownMenuItem(value: 'heterosexual',    child: Text('Heterosexual')),
            DropdownMenuItem(value: 'gay',             child: Text('Gay')),
            DropdownMenuItem(value: 'lesbiana',        child: Text('Lesbiana')),
            DropdownMenuItem(value: 'bisexual',        child: Text('Bisexual')),
            DropdownMenuItem(value: 'pansexual',       child: Text('Pansexual')),
            DropdownMenuItem(value: 'prefiero_no_decir', child: Text('Prefiero no decir')),
          ],
          onChanged: (v) => setState(() => _orientacion = v!),
        ),
        const SizedBox(height: 16),
        _sectionLabel('Me interesa conocer (pareja)'),
        const SizedBox(height: 8),
        _multiChips(['hombres', 'mujeres', 'otros', 'todos'], _interesadoEnPareja),
        const SizedBox(height: 16),
      ],
      if (_intenciones.contains('amistad')) ...[
        _sectionLabel('Me interesa hacer amistad con'),
        const SizedBox(height: 8),
        _multiChips(['hombres', 'mujeres', 'otros', 'todos'], _interesadoEnAmistad),
      ],
    ]);
  }

  // ── PASO 4: Personal ──────────────────────────────────────────
  Widget _buildPersonal() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Sobre ti',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 16),
      _field(_bioCtrl, 'Bio corta (máx 100 chars)', Icons.edit_note,
          maxLength: 100),
      const SizedBox(height: 12),
      _field(_bioLargaCtrl, 'Cuéntanos más sobre ti...', Icons.article_outlined,
          maxLines: 4),
      const SizedBox(height: 16),
      _sectionLabel('Gustos / Hobbies (máx 15)'),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        ..._gustos.map((g) => Chip(
          label: Text(g, style: const TextStyle(fontSize: 12)),
          onDeleted: () => setState(() => _gustos.remove(g)),
          deleteIconColor: KoraColors.textSecondary,
          backgroundColor: KoraColors.primary.withOpacity(0.08),
        )),
        if (_gustos.length < 15)
          ActionChip(
            label: const Text('+ Agregar'),
            backgroundColor: KoraColors.bg,
            onPressed: () async {
              final t = await _inputDialog('Agregar gusto');
              if (t != null && t.isNotEmpty) setState(() => _gustos.add(t));
            },
          ),
      ]),
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
      _switchTile('¿Te gustan los animales?', _animalesGustan,
          (v) => setState(() => _animalesGustan = v)),
      _switchTile('¿Tienes mascotas?', _tieneAnimales,
          (v) => setState(() => _tieneAnimales = v)),
      if (_tieneAnimales) ...[
        const SizedBox(height: 8),
        _field(_animalesCtrl, '¿Cuáles? (perro, gato...)', Icons.pets),
      ],
    ],
  );

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

  // ── PASO 5: Institucional ─────────────────────────────────────
  Widget _buildInstitucional() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Tu vida universitaria',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 20),
      _field(_facultadCtrl, 'Facultad', Icons.school_outlined),
      const SizedBox(height: 12),
      _field(_carreraCtrl,  'Carrera',  Icons.book_outlined),
      const SizedBox(height: 16),
      Row(children: [
        const Text('Semestre: ',
            style: TextStyle(fontWeight: FontWeight.w600,
                color: KoraColors.textPrimary)),
        ShaderMask(
          shaderCallback: (b) => KoraGradients.mainGradient.createShader(b),
          child: Text('$_semestre',
            style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 18, color: Colors.white)),
        ),
      ]),
      Slider(
        value: _semestre.toDouble(), min: 1, max: 12, divisions: 11,
        label: 'Semestre $_semestre',
        activeColor: KoraColors.primary,
        inactiveColor: KoraColors.divider,
        onChanged: (v) => setState(() => _semestre = v.round()),
      ),
      const SizedBox(height: 8),
      _dropdown<String>(
        label: '¿Cómo te va con tu carrera?', value: _gustaCarrera,
        items: const [
          DropdownMenuItem(value: 'la_amo',   child: Text('La amo ❤️')),
          DropdownMenuItem(value: 'esta_ok',  child: Text('Está bien 👍')),
          DropdownMenuItem(value: 'no_mucho', child: Text('No mucho 😐')),
          DropdownMenuItem(value: 'la_odio',  child: Text('La odio 😤')),
        ],
        onChanged: (v) => setState(() => _gustaCarrera = v!),
      ),
    ],
  );

  // ── PASO 6: Disponibilidad ────────────────────────────────────
  Widget _buildDisponibilidad() {
    const zonas = ['cafetería', 'biblioteca', 'patio', 'canchas', 'general'];
    const zonaIcons = {
      'cafetería': Icons.coffee_outlined,
      'biblioteca': Icons.menu_book_outlined,
      'patio': Icons.park_outlined,
      'canchas': Icons.sports_soccer_outlined,
      'general': Icons.location_on_outlined,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Disponibilidad',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('¿Dónde sueles estar y cuándo te encontramos?',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 24),

      _sectionLabel('Campus — zona habitual'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: zonas.map((z) {
        final sel = _campusZona == z;
        return GestureDetector(
          onTap: () => setState(() => _campusZona = z),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: sel ? KoraGradients.mainGradient : null,
              color: sel ? null : KoraColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? Colors.transparent : KoraColors.divider),
              boxShadow: sel ? [BoxShadow(
                color: KoraColors.primary.withOpacity(0.2),
                blurRadius: 8)] : [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(zonaIcons[z] ?? Icons.location_on_outlined,
                size: 16,
                color: sel ? Colors.white : KoraColors.textSecondary),
              const SizedBox(width: 6),
              Text(z[0].toUpperCase() + z.substring(1),
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : KoraColors.textPrimary)),
            ]),
          ),
        );
      }).toList()),

      const SizedBox(height: 24),
      Row(children: [
        _sectionLabel('Radio de búsqueda'),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (b) => KoraGradients.mainGradient.createShader(b),
          child: Text('$_rangoDistancia km',
            style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 16, color: Colors.white)),
        ),
      ]),
      Slider(
        value: _rangoDistancia.toDouble(),
        min: 1, max: 20, divisions: 19,
        label: '$_rangoDistancia km',
        activeColor: KoraColors.primary,
        inactiveColor: KoraColors.divider,
        onChanged: (v) => setState(() => _rangoDistancia = v.round()),
      ),

      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _disponibleAhora
              ? KoraColors.like.withOpacity(0.08)
              : KoraColors.bgCard,
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
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: _disponibleAhora
                  ? KoraColors.like : KoraColors.textPrimary))),
          Switch(
            value: _disponibleAhora,
            onChanged: (v) => setState(() => _disponibleAhora = v),
            activeColor: KoraColors.like),
        ]),
      ),
    ]);
  }

  // ── PASO 7: Fotos ─────────────────────────────────────────────
  Widget _buildFotos() {
    final aprobadas = _fotos.where((f) => f['estado'] == 'approved').length;
    final pendientes = _fotos.where((f) => f['estado'] == 'pending').length;

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
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: _fotos.length < 5 ? _fotos.length + 1 : _fotos.length,
        itemBuilder: (ctx, i) {
          // Botón agregar
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
                    style: BorderStyle.solid,
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

          final foto = _fotos[i];
          final estado = foto['estado'] as String;
          final previewBytes = foto['previewBytes'] as Uint8List?;
          final urlMedium = foto['url_medium'] as String?;

          return Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildFotoPreview(previewBytes, urlMedium, estado),
            ),
            // Overlay de estado
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
                    const Text('Procesando', style: TextStyle(
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
                  color: KoraColors.pass.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Icon(Icons.block,
                    color: Colors.white, size: 28)),
              )),
            // Botón eliminar
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
            // Badge principal
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
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KoraColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KoraColors.primary.withOpacity(0.2)),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline, color: KoraColors.primary, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Sube mínimo 2 fotos. Las fotos deben mostrarte a ti.',
              style: TextStyle(color: KoraColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
            )),
          ]),
          SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, color: KoraColors.textHint, size: 14),
            SizedBox(width: 6),
            Expanded(child: Text(
              'Kora aplica filtros automáticos como mejor esfuerzo. El uso de fotos es voluntario. '
              'La plataforma no se hace responsable del contenido subido por usuarios.',
              style: TextStyle(color: KoraColors.textHint, fontSize: 11, height: 1.5),
            )),
          ]),
        ]),
      ),
    ]);
  }

  Widget _buildFotoPreview(Uint8List? bytes, String? urlMedium, String estado) {
    // 1. Preview local inmediato (antes de que el worker procese)
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    // 2. URL del servidor (después del procesamiento)
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
    // 3. Placeholder
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
      // Leer bytes para preview inmediato
      final bytes = await img.readAsBytes();

      // Crear entrada local con preview inmediato
      final fotoLocal = {
        'id':           null,
        'estado':       'uploading',
        'previewBytes': bytes,
        'url_medium':   null,
      };
      setState(() {
        _fotos.add(fotoLocal);
        _loading = false;
      });

      // Subir al servidor
      dynamic fileArg = kIsWeb ? bytes : img.path;
      final data = await ApiClient.postMultipart(
        '/api/v1/onboarding/fotos/', fileArg,
        fields: {'es_principal': _fotos.length == 1 ? 'true' : 'false'},
      );

      // Actualizar con datos del servidor
      final idx = _fotos.indexOf(fotoLocal);
      if (idx >= 0 && mounted) {
        setState(() {
          _fotos[idx] = {
            'id':           data['id'],
            'estado':       data['estado'] ?? 'pending',
            'previewBytes': bytes,         // mantener preview local
            'url_medium':   data['url_medium'],
          };
        });
        // Polling ligero para ver si el worker aprobó la foto
        _pollFotoEstado(data['id'], idx);
      }
    } on ApiException catch (e) {
      // Remover la foto local si falló el upload
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

  /// Polling para ver si el worker procesó la foto (máx 30 segundos)
  Future<void> _pollFotoEstado(int fotoId, int idx) async {
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final fotas = await ApiClient.get('/api/v1/onboarding/fotos/lista/');
        if (fotas is List) {
          final fotoData = fotas.firstWhere(
              (f) => f['id'] == fotoId, orElse: () => null);
          if (fotoData != null && mounted) {
            setState(() {
              if (idx < _fotos.length) {
                _fotos[idx] = {
                  ..._fotos[idx],
                  'estado':     fotoData['estado'],
                  'url_medium': fotoData['url_medium'],
                };
              }
            });
            if (fotoData['estado'] != 'pending') return;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _eliminarFoto(int idx, int? fotoId) async {
    if (fotoId != null) {
      try {
        await ApiClient.delete('/api/v1/onboarding/fotos/$fotoId/');
      } catch (_) {}
    }
    if (mounted) setState(() {
      if (idx < _fotos.length) _fotos.removeAt(idx);
    });
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
          if (_paso == 7) _cargarFotosExistentes();
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
      switch (_paso) {
        case 0:
          if (!_aceptoTc || !_aceptoDatos) {
            setState(() => _error = 'Debes aceptar los dos puntos para continuar.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/terminos/',
              body: {'acepto_terminos': true, 'acepto_datos': true});

        case 1:
          if (_nombreCtrl.text.trim().isEmpty || _apellidoCtrl.text.trim().isEmpty) {
            setState(() => _error = 'Nombre y apellido son obligatorios.');
            return false;
          }
          if (_fechaNac == null) {
            setState(() => _error = 'Selecciona tu fecha de nacimiento.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/basico/', body: {
            'nombre':   _nombreCtrl.text.trim(),
            'apellido': _apellidoCtrl.text.trim(),
            'fecha_nacimiento': '${_fechaNac!.year}-'
                '${_fechaNac!.month.toString().padLeft(2,'0')}-'
                '${_fechaNac!.day.toString().padLeft(2,'0')}',
            'genero': _genero,
          });

        case 2:
          if (_intenciones.isEmpty) {
            setState(() => _error = 'Selecciona al menos una intención.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/intenciones/',
              body: {'intenciones': _intenciones.toList()});

        case 3:
          await ApiClient.post('/api/v1/onboarding/preferencias/', body: {
            'orientacion_sexual':    _orientacion,
            'interesado_en_pareja':  _interesadoEnPareja,
            'interesado_en_amistad': _interesadoEnAmistad,
          });

        case 4:
          await ApiClient.post('/api/v1/onboarding/personal/', body: {
            'bio_corta':       _bioCtrl.text,
            'bio_larga':       _bioLargaCtrl.text,
            'gustos':          _gustos,
            'fuma':            _fuma,
            'bebe':            _bebe,
            'sale_fiesta':     _fiesta,
            'animales_gustan': _animalesGustan,
            'tiene_animales':  _tieneAnimales,
            'cuales_animales': _animalesCtrl.text,
          });

        case 5:
          if (_facultadCtrl.text.trim().isEmpty || _carreraCtrl.text.trim().isEmpty) {
            setState(() => _error = 'Facultad y carrera son obligatorias.');
            return false;
          }
          await ApiClient.post('/api/v1/onboarding/institucional/', body: {
            'facultad':     _facultadCtrl.text.trim(),
            'carrera':      _carreraCtrl.text.trim(),
            'semestre':     _semestre,
            'gusta_carrera': _gustaCarrera,
          });

        case 6:
          await ApiClient.patch('/api/v1/users/me/profile/', body: {
            'campus_zona':      _campusZona,
            'rango_distancia':  _rangoDistancia,
            'disponible_ahora': _disponibleAhora,
          });
      }
      return true;
    } on ApiException catch (e) {
      // Si el error es "Paso incorrecto", saltar al paso correcto
      final msg = e.message;
      if (msg.contains('Paso incorrecto') || msg.contains('paso_actual')) {
        final pasoActual = _extraerPasoError(msg);
        if (pasoActual != null) {
          final indice = _pasoAIndice[pasoActual] ?? _paso;
          setState(() {
            _error = null;
            _paso  = indice;
          });
          return true; // Avanzar a la pantalla correcta
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
          'Tus fotos ($pendientes) aún están siendo procesadas. '
          'Espera un momento y vuelve a intentarlo.');
      } else {
        setState(() => _error =
          'Necesitas al menos 2 fotos para completar tu perfil.');
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

  Widget _multiChips(List<String> opciones, List<String> seleccionados) {
    return Wrap(spacing: 8, runSpacing: 8, children: opciones.map((o) {
      final sel = seleccionados.contains(o);
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
          child: Text(o, style: TextStyle(
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
