import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class LeagueEmptyState extends StatelessWidget {
  final VoidCallback onJoin;
  final VoidCallback onCreate;
  final VoidCallback onExplore;

  const LeagueEmptyState({
    super.key,
    required this.onJoin,
    required this.onCreate,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.slate800),
              ),
              child: const Icon(Icons.emoji_events_outlined,
                  size: 48, color: AppColors.amber300),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tienes ninguna liga activa',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una liga para registrar participantes o únete a una existente con su clave.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.vpn_key_outlined,
                        size: 16, color: AppColors.amber300),
                    label: const Text('Unirse con Clave',
                        style: TextStyle(color: AppColors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.slate700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Crear Liga',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.cloud_outlined,
                    size: 16, color: AppColors.emerald400),
                label: const Text(
                  'Ver Ligas Registradas en la Nube / Dispositivo',
                  style: TextStyle(
                      color: AppColors.emerald400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
