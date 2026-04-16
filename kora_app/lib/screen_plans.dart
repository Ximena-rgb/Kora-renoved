import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_plans.dart';
import 'api_client.dart';

int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  String _tipo = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlansProvider>().cargarPlanes();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              const Text('Planes',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                    color: KoraColors.textPrimary, letterSpacing: -0.5)),
              const Spacer(),
              GestureDetector(
                onTap: _crearPlan,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: KoraGradients.mainGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: KoraColors.primary.withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),
          // Filtros
          _buildFiltros(),
          // Feed
          Expanded(child: _buildFeed()),
        ]),
      ),
    );
  }

  Widget _buildFiltros() {
    final tipos = {'': 'Todos', 'social': '🎉 Social', 'estudio': '📚 Estudio', 'date': '💑 Date'};
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tipos.entries.map((e) {
          final sel = _tipo == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _tipo = e.key);
                context.read<PlansProvider>().cargarPlanes(tipo: e.key.isEmpty ? null : e.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: sel ? KoraGradients.mainGradient : null,
                  color: sel ? null : KoraColors.bgElevated,
                  borderRadius: BorderRadius.circular(22),
                  border: sel ? null : Border.all(color: KoraColors.divider),
                ),
                child: Text(e.value,
                  style: TextStyle(
                    color: sel ? Colors.white : KoraColors.textSecondary,
                    fontWeight: FontWeight.w600, fontSize: 13,
                  )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeed() {
    return Consumer<PlansProvider>(
      builder: (_, pp, __) {
        if (pp.loading) return const Center(
            child: CircularProgressIndicator(color: KoraColors.primary, strokeWidth: 2));
        if (pp.planes.isEmpty) return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('📅', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('No hay planes activos', style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w700, color: KoraColors.textPrimary)),
            SizedBox(height: 6),
            Text('¡Sé el primero en crear uno!',
                style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
          ]),
        );
        return RefreshIndicator(
          onRefresh: () => pp.cargarPlanes(tipo: _tipo.isEmpty ? null : _tipo),
          color: KoraColors.primary,
          backgroundColor: KoraColors.bgCard,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            itemCount: pp.planes.length,
            itemBuilder: (_, i) => _PlanCard(plan: pp.planes[i]),
          ),
        );
      },
    );
  }

  Future<void> _crearPlan() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KoraColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _CrearPlanSheet(),
    );
    if (mounted) context.read<PlansProvider>().cargarPlanes();
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final yaAsiste     = plan['ya_asisto'] == true;
    final lleno        = plan['esta_lleno'] == true;
    final puedeCheckin = plan['puede_checkin'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KoraColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (plan['foto_url'] != null && (plan['foto_url'] as String).isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              '${ApiClient.baseUrl}${plan["foto_url"]}',
              height: 160, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 80, color: KoraColors.bgElevated),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _tipoBadge(plan['tipo'] ?? ''),
              const Spacer(),
              Text('${_toInt(plan["participantes_count"])}/${_toInt(plan["max_personas"])} 👥',
                style: const TextStyle(fontSize: 13, color: KoraColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(plan['titulo'] ?? '',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                  color: KoraColors.textPrimary)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: KoraColors.textHint),
              const SizedBox(width: 4),
              Expanded(child: Text(plan['ubicacion'] ?? '',
                style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
              const Icon(Icons.access_time_rounded, size: 14, color: KoraColors.textHint),
              const SizedBox(width: 4),
              Text(_formatFecha(plan['hora_inicio'] ?? ''),
                style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
            ]),
            if ((plan['tags'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: (plan['tags'] as List).take(3).map((t) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: KoraColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KoraColors.divider),
                  ),
                  child: Text(t, style: const TextStyle(fontSize: 11,
                      color: KoraColors.textSecondary, fontWeight: FontWeight.w500)),
                )
              ).toList()),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: puedeCheckin && yaAsiste
                ? ElevatedButton.icon(
                    onPressed: () => _doCheckin(context, plan['id']),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Check-in ✅'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KoraColors.like, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : ElevatedButton(
                    onPressed: lleno && !yaAsiste ? null : () => _toggleAsistencia(context, plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yaAsiste ? KoraColors.bgElevated : KoraColors.primary,
                      foregroundColor: yaAsiste ? KoraColors.textSecondary : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(yaAsiste ? 'Ya asisto ✓' : lleno ? 'Lleno' : 'Asistir'),
                  ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tipoBadge(String tipo) {
    final map = {
      'social':  ('🎉 Social',  const Color(0xFFFF9500)),
      'estudio': ('📚 Estudio', const Color(0xFF0A84FF)),
      'date':    ('💑 Date',    KoraColors.match),
    };
    final info = map[tipo];
    final label = info?.$1 ?? '📅';
    final color = info?.$2 ?? KoraColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  String _formatFecha(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final hoy = DateTime.now();
      if (d.day == hoy.day && d.month == hoy.month) return 'Hoy ${d.hour}:${d.minute.toString().padLeft(2,'0')}';
      return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  Future<void> _toggleAsistencia(BuildContext ctx, Map<String, dynamic> plan) async {
    try {
      if (plan['ya_asisto'] == true) {
        await ApiClient.post('/api/v1/plans/${plan["id"]}/cancelar/');
      } else {
        await ApiClient.post('/api/v1/plans/${plan["id"]}/asistir/');
      }
      if (ctx.mounted) ctx.read<PlansProvider>().cargarPlanes();
    } on ApiException catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: KoraColors.bgElevated));
    }
  }

  Future<void> _doCheckin(BuildContext ctx, int planId) async {
    try {
      final data = await ApiClient.post('/api/v1/plans/$planId/checkin/');
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(data['puntual'] == true ? '✅ Check-in puntual! +3 puntos' : '⏰ Check-in registrado'),
        backgroundColor: data['puntual'] == true ? KoraColors.like : KoraColors.bgElevated,
      ));
    } on ApiException catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: KoraColors.bgElevated));
    }
  }
}

class _CrearPlanSheet extends StatefulWidget {
  const _CrearPlanSheet();
  @override State<_CrearPlanSheet> createState() => _CrearPlanSheetState();
}

class _CrearPlanSheetState extends State<_CrearPlanSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _ubicCtrl  = TextEditingController();
  String _tipo     = 'social';
  DateTime? _hora;
  int _max         = 10;
  bool _loading    = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: KoraColors.divider,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Crear plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: KoraColors.textPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _tipo,
            dropdownColor: KoraColors.bgElevated,
            style: const TextStyle(color: KoraColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'social',  child: Text('🎉 Social / Parche')),
              DropdownMenuItem(value: 'estudio', child: Text('📚 Grupo de Estudio')),
              DropdownMenuItem(value: 'date',    child: Text('💑 Date')),
            ],
            onChanged: (v) => setState(() => _tipo = v!),
          ),
          const SizedBox(height: 14),
          TextField(controller: _titleCtrl, style: const TextStyle(color: KoraColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Título')),
          const SizedBox(height: 14),
          TextField(controller: _descCtrl, maxLines: 2, style: const TextStyle(color: KoraColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Descripción')),
          const SizedBox(height: 14),
          TextField(controller: _ubicCtrl, style: const TextStyle(color: KoraColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Ubicación en campus')),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(context: context,
                  initialDate: DateTime.now().add(const Duration(hours: 2)),
                  firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
              if (d == null || !mounted) return;
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (t == null) return;
              setState(() => _hora = DateTime(d.year, d.month, d.day, t.hour, t.minute));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: KoraColors.bgElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KoraColors.divider),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: KoraColors.primary, size: 18),
                const SizedBox(width: 12),
                Text(_hora == null ? 'Seleccionar fecha y hora'
                    : '${_hora!.day}/${_hora!.month} ${_hora!.hour}:${_hora!.minute.toString().padLeft(2,"0")}',
                  style: TextStyle(color: _hora == null ? KoraColors.textHint : KoraColors.textPrimary)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            const Text('Máx personas:', style: TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
            Expanded(child: Slider(
              value: _max.toDouble(), min: 2, max: 50, divisions: 48,
              label: '$_max',
              activeColor: KoraColors.primary,
              inactiveColor: KoraColors.bgElevated,
              onChanged: (v) => setState(() => _max = v.round()),
            )),
            Text('$_max', style: const TextStyle(color: KoraColors.textPrimary, fontWeight: FontWeight.w700)),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: KoraColors.pass, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          KoraGradientButton(
            label: _loading ? 'Creando...' : 'Crear plan',
            loading: _loading,
            onPressed: _crear,
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _crear() async {
    if (_titleCtrl.text.trim().isEmpty || _hora == null || _ubicCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Completa título, ubicación y hora.'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.post('/api/v1/plans/crear/', body: {
        'tipo':        _tipo,
        'titulo':      _titleCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'ubicacion':   _ubicCtrl.text.trim(),
        'hora_inicio': _hora!.toIso8601String(),
        'max_personas': _max,
        'es_publico': true,
      });
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    }
  }
}
