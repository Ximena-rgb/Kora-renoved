import 'package:flutter/material.dart';
import 'theme.dart';
import 'api_client.dart';

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final fotoUrl = user['foto_url'] as String?;
    final nombre  = user['nombre'] as String? ?? '';
    final carrera = user['carrera'] as String? ?? '';
    final edad    = user['edad'];

    return Container(
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KoraColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
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
        title: Text(
          edad != null ? '$nombre, $edad' : nombre,
          style: const TextStyle(fontWeight: FontWeight.w700,
              color: KoraColors.textPrimary, fontSize: 15),
        ),
        subtitle: Text(carrera,
            style: const TextStyle(color: KoraColors.textSecondary, fontSize: 13)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: KoraColors.textHint, size: 20),
      ),
    );
  }
}
