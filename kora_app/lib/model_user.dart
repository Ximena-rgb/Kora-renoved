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
  final bool disponible;
  final String campus_zona;
  final double reputacion;
  final int totalRatings;
  final bool perfilCompleto;
  final bool mfaActivo;
  final double? scoreConfianza;

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
    this.scoreConfianza,
  });

  factory UserModel.fromApi(Map<String, dynamic> j) => UserModel(
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
    scoreConfianza: j['score_confianza'] != null
                    ? _toDouble(j['score_confianza'])
                    : null,
  );

  UserModel copyWith({
    String? nombre, String? foto_url, String? bio,
    List<String>? intereses, bool? disponible,
    String? campus_zona, bool? perfilCompleto,
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
  );
}
