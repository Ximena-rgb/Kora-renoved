// Helper que convierte num o String a double de forma segura
double _toDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

// Helper que convierte num o String a int de forma segura
int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// Estados de disponibilidad del usuario.
/// [enClases] es automático cuando el horario coincide; no lo elige el usuario.
enum EstadoUsuario {
  disponible,  // 🟢 Libre para conectar
  ocupado,     // 🟡 Presente pero ocupado
  ausente,     // 🔴 No disponible / fuera del campus
  enClases,    // 📚 Automático durante clases
}

extension EstadoUsuarioX on EstadoUsuario {
  String get apiValue {
    switch (this) {
      case EstadoUsuario.disponible: return 'disponible';
      case EstadoUsuario.ocupado:    return 'ocupado';
      case EstadoUsuario.ausente:    return 'ausente';
      case EstadoUsuario.enClases:   return 'en_clases';
    }
  }

  static EstadoUsuario fromApi(String? v) {
    switch (v) {
      case 'disponible': return EstadoUsuario.disponible;
      case 'ocupado':    return EstadoUsuario.ocupado;
      case 'ausente':    return EstadoUsuario.ausente;
      case 'en_clases':  return EstadoUsuario.enClases;
      default:           return EstadoUsuario.ausente;
    }
  }

  String get label {
    switch (this) {
      case EstadoUsuario.disponible: return 'Disponible';
      case EstadoUsuario.ocupado:    return 'Ocupado';
      case EstadoUsuario.ausente:    return 'Ausente';
      case EstadoUsuario.enClases:   return 'En clases';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String nombre;
  final String? foto_url;
  final String carrera;
  final String facultad;
  final int semestre;
  final String bio;
  final List<String> intereses;
  final bool disponible;           // legacy — mantenido para compatibilidad API
  final String campus_zona;
  final double reputacion;
  final int totalRatings;
  final bool perfilCompleto;
  final bool mfaActivo;
  final double? reputacionScore;
  final EstadoUsuario estado;      // nuevo campo unificado de estado
  final List<Map<String, String>> horarioClases; // bloques de clase para auto-detección

  const UserModel({
    required this.id,
    required this.email,
    required this.nombre,
    this.foto_url,
    required this.carrera,
    required this.facultad,
    required this.semestre,
    required this.bio,
    required this.intereses,
    required this.disponible,
    required this.campus_zona,
    required this.reputacion,
    required this.totalRatings,
    required this.perfilCompleto,
    required this.mfaActivo,
    this.reputacionScore,
    this.estado = EstadoUsuario.ausente,
    this.horarioClases = const [],
  });

  factory UserModel.fromApi(Map<String, dynamic> j) {
    // Parsear horario_clases si viene del API
    List<Map<String, String>> horario = [];
    final raw = j['horario_clases'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          horario.add({
            'dia':     item['dia']?.toString() ?? '',
            'inicio':  item['inicio']?.toString() ?? '',
            'fin':     item['fin']?.toString() ?? '',
            'materia': item['materia']?.toString() ?? '',
          });
        }
      }
    }

    // Derivar estado desde campo 'estado' o desde 'disponible' legacy
    final estadoRaw = j['estado']?.toString();
    EstadoUsuario estado;
    if (estadoRaw != null) {
      estado = EstadoUsuarioX.fromApi(estadoRaw);
    } else {
      estado = (j['disponible'] == true)
          ? EstadoUsuario.disponible
          : EstadoUsuario.ausente;
    }

    return UserModel(
      id:             j['id']?.toString() ?? '',
      email:          j['email'] ?? '',
      nombre:         j['nombre'] ?? '',
      foto_url:       j['foto_url'],
      carrera:        j['carrera'] ?? '',
      facultad:       j['facultad'] ?? '',
      semestre:       _toInt(j['semestre'], 1),
      bio:            j['bio'] ?? '',
      intereses:      List<String>.from(j['intereses'] ?? []),
      disponible:     j['disponible'] ?? false,
      campus_zona:    j['campus_zona'] ?? '',
      reputacion:     _toDouble(j['reputacion']),
      totalRatings:   _toInt(j['total_ratings']),
      perfilCompleto: j['perfil_completo'] ?? false,
      mfaActivo:      j['mfa_activo'] ?? false,
      reputacionScore: j['reputacion_score'] != null
                      ? _toDouble(j['reputacion_score'])
                      : null,
      estado:         estado,
      horarioClases:  horario,
    );
  }

  UserModel copyWith({
    String? nombre, String? foto_url, String? bio,
    List<String>? intereses, bool? disponible,
    String? campus_zona, bool? perfilCompleto,
    EstadoUsuario? estado,
    List<Map<String, String>>? horarioClases,
  }) => UserModel(
    id: id, email: email,
    nombre:         nombre       ?? this.nombre,
    foto_url:       foto_url     ?? this.foto_url,
    carrera: carrera, facultad: facultad, semestre: semestre,
    bio:            bio          ?? this.bio,
    intereses:      intereses    ?? this.intereses,
    disponible:     disponible   ?? this.disponible,
    campus_zona:    campus_zona  ?? this.campus_zona,
    reputacion: reputacion, totalRatings: totalRatings,
    perfilCompleto: perfilCompleto ?? this.perfilCompleto,
    mfaActivo: mfaActivo,
    estado:         estado       ?? this.estado,
    horarioClases:  horarioClases ?? this.horarioClases,
  );

  /// Devuelve true si ahora mismo hay una clase activa en el horario.
  bool get estaEnClasesAhora {
    if (horarioClases.isEmpty) return false;
    final ahora = DateTime.now();
    final diasMap = {
      'lunes': 1, 'martes': 2, 'miércoles': 3, 'miercoles': 3,
      'jueves': 4, 'viernes': 5, 'sábado': 6, 'sabado': 6, 'domingo': 7,
    };
    for (final bloque in horarioClases) {
      final diaNum = diasMap[bloque['dia']?.toLowerCase() ?? ''];
      if (diaNum == null || diaNum != ahora.weekday) continue;
      final inicioPartes = bloque['inicio']?.split(':');
      final finPartes    = bloque['fin']?.split(':');
      if (inicioPartes == null || finPartes == null) continue;
      if (inicioPartes.length < 2 || finPartes.length < 2) continue;
      final inicioMin = int.tryParse(inicioPartes[0])! * 60 + int.tryParse(inicioPartes[1])!;
      final finMin    = int.tryParse(finPartes[0])!   * 60 + int.tryParse(finPartes[1])!;
      final ahoraMin  = ahora.hour * 60 + ahora.minute;
      if (ahoraMin >= inicioMin && ahoraMin < finMin) return true;
    }
    return false;
  }

  /// Estado efectivo: si hay clase activa, devuelve enClases independientemente del estado manual.
  EstadoUsuario get estadoEfectivo =>
      estaEnClasesAhora ? EstadoUsuario.enClases : estado;
}
