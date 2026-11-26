import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../theme/app_colors.dart';

class LocalLeaguesTab extends StatelessWidget {
  final List<League> localLeagues;
  final String? activeId;
  final VoidCallback onCreateLeague;
  final ValueChanged<League> onActivateLeague;
  final ValueChanged<League> onDeleteLeague;

  const LocalLeaguesTab({
    super.key,
    required this.localLeagues,
    required this.activeId,
    required this.onCreateLeague,
    required this.onActivateLeague,
    required this.onDeleteLeague,
  });

  @override
  Widget build(BuildContext context) {
    if (localLeagues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_outlined,
                  size: 54, color: AppColors.slate600),
              const SizedBox(height: 16),
              const Text(
                'No tienes ligas registradas en este dispositivo',
                style: TextStyle(
                    color: AppColors.slate300,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea una liga nueva o explora la pestaña "En el Servidor" para unirte con tu PIN.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onCreateLeague,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Crear Primera Liga',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: localLeagues.length + 2,
      itemBuilder: (ctx, index) {
        if (index == 0) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIGAS REGISTRADAS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate400,
                    letterSpacing: 1),
              ),
              TextButton.icon(
                onPressed: onCreateLeague,
                icon: const Icon(Icons.add,
                    size: 15, color: AppColors.emerald400),
                label: const Text('Nueva Liga',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.emerald400,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
        if (index == 1) return const SizedBox(height: 8);

        final league = localLeagues[index - 2];
        final isActive = league.id == activeId;

        return LocalLeagueCard(
          key: ValueKey('local_league_${league.id}'),
          league: league,
          isActive: isActive,
          onActivate: () => onActivateLeague(league),
          onDelete: () => onDeleteLeague(league),
        );
      },
    );
  }
}

class LocalLeagueCard extends StatelessWidget {
  final League league;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  const LocalLeagueCard({
    super.key,
    required this.league,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.emerald500 : AppColors.slate800,
          width: isActive ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        (isActive ? AppColors.emerald500 : AppColors.slate700)
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: isActive ? AppColors.emerald400 : AppColors.slate400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        league.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.slate800,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '# ${league.id}',
                              style: const TextStyle(
                                  color: AppColors.slate300,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amber950.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PIN: ${league.pin}',
                              style: const TextStyle(
                                  color: AppColors.amber300,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emerald500),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 13, color: AppColors.emerald400),
                        SizedBox(width: 4),
                        Text('ACTIVA',
                            style: TextStyle(
                                color: AppColors.emerald300,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.slate800, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  '${league.participants.length} participantes',
                  style:
                      const TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.history, size: 14, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  '${league.matches.length} partidas',
                  style:
                      const TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
                const Spacer(),
                if (!isActive) ...[
                  ElevatedButton(
                    onPressed: onActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate800,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Activar',
                        style: TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline,
                            size: 14, color: Colors.redAccent),
                        SizedBox(width: 4),
                        Text(
                          'Eliminar',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
