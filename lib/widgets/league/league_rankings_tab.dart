import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../theme/app_colors.dart';

class LeagueRankingsTab extends StatelessWidget {
  final League league;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onOpenMonthlyRanking;

  const LeagueRankingsTab({
    super.key,
    required this.league,
    required this.isSyncing,
    required this.onSync,
    required this.onOpenMonthlyRanking,
  });

  @override
  Widget build(BuildContext context) {
    final teams = league.teamsRanked;
    final players = league.playersRanked;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'RANKING DE PAREJAS / EQUIPOS',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald400,
                      letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onSync,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.emerald500.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          size: 12, color: AppColors.emerald400),
                      const SizedBox(width: 4),
                      Text(
                        isSyncing ? 'Sincronizando...' : 'Sincronizar Servidor',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onOpenMonthlyRanking,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.emerald600.withValues(alpha: 0.2),
                    AppColors.slate900,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.emerald500.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_month,
                      color: AppColors.emerald400, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ver Ranking Mensual Dinámico',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          'Filtra por mes/año, podio y clasificaciones por parejas e individual',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: AppColors.emerald400, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (teams.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate800),
              ),
              child: const Text(
                'Aún no hay partidas jugadas en esta liga. Inicia una partida para generar la clasificación.',
                style: TextStyle(fontSize: 12, color: AppColors.slate400),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final t = teams[i];
                return Container(
                  key: ValueKey('home_team_${t.key}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.slate900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate800),
                  ),
                  child: Row(
                    children: [
                      Text('#${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate400)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t.displayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emerald950,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.emerald500.withValues(alpha: 0.3)),
                        ),
                        child: Text('${t.wins} V',
                            style: const TextStyle(
                                color: AppColors.emerald400,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
          const Text(
            'RANKING INDIVIDUAL DE JUGADORES',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.indigo400,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          if (players.isEmpty)
            const Text('Sin datos individuales aún.',
                style: TextStyle(fontSize: 12, color: AppColors.slate500))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final p = players[i];
                return Container(
                  key: ValueKey('home_player_${p.key}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.slate900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate800),
                  ),
                  child: Row(
                    children: [
                      Text('#${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate400)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      Text('${p.matchesPlayed} jugadas • ',
                          style: const TextStyle(
                              color: AppColors.slate500, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.indigo950,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.indigo500.withValues(alpha: 0.3)),
                        ),
                        child: Text('${p.wins} V',
                            style: const TextStyle(
                                color: AppColors.indigo400,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
