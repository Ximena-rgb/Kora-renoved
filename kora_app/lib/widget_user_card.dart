import 'package:flutter/material.dart';
import 'theme.dart';
import 'api_client.dart';

/// Badge de color según el estado del usuario
Widget _estadoBadge(String? estado) {
  if (estado == null || estado.isEmpty || estado == 'activo') {
    return const SizedBox.shrink();
  }

  final Map<String, _EstadoInfo> info = {
    'ocupado':   _EstadoInfo('Ocupado',    const Color(0xFFFF9800)),
    'inactivo':  _EstadoInfo('Inactivo',   const Color(0xFF9E9E9E)),
    'en_clases': _EstadoInfo('En clases',  const Color(0xFF5C6BC0)),
  };

  final e = info[estado];
  if (e == null) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: e.color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: e.color.withOpacity(0.4)),
    ),
    child: Text(
      e.label,
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600, color: e.color,
      ),
    ),
  );
}

class _EstadoInfo {
  final String label;
  final Color color;
  const _EstadoInfo(this.label, this.color);
}

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final fotoUrl     = user['foto_url'] as String?;
    final nombre      = user['nombre'] as String? ?? '';
    final carrera     = user['carrera'] as String? ?? '';
    final edad        = user['edad'];
    final estado      = user['estado_usuario'] as String?;
    final reputacion  = user['reputacion'];

    return Container(
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KoraColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: KoraColors.primary.withOpacity(0.12),
              backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                  ? NetworkImage('${ApiClient.baseUrl}$fotoUrl')
                  : null,
              child: fotoUrl == null || fotoUrl.isEmpty
                  ? Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          color: KoraColors.primary, fontSize: 16))
                  : null,
            ),
            // Indicador de estado activo (punto verde)
            if (estado == null || estado == 'activo')
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(color: KoraColors.bgCard, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                edad != null ? '$nombre, $edad' : nombre,
                style: const TextStyle(fontWeight: FontWeight.w700,
                    color: KoraColors.textPrimary, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _estadoBadge(estado),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(carrera,
                style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
            if (reputacion != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB300)),
                  const SizedBox(width: 3),
                  Text(
                    'Reputación: $reputacion',
                    style: const TextStyle(fontSize: 11, color: KoraColors.textHint),
                  ),
                ]),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: KoraColors.textHint, size: 20),
      ),
    );
  }
}
