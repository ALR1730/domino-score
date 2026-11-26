import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../theme/app_colors.dart';

class LeagueMatchesHistoryTab extends StatelessWidget {
  final List<LeagueMatch> matches;

  const LeagueMatchesHistoryTab({
    super.key,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Text(
          'Sin partidas jugadas aún en esta liga.',
          style: TextStyle(color: AppColors.slate500, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final m = matches[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${m.date.day}/${m.date.month}/${m.date.year}',
                    style: const TextStyle(
                        color: AppColors.slate500, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      m.winnerTeam == 1
                          ? 'Ganó ${m.team1DisplayName}'
                          : 'Ganó ${m.team2DisplayName}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: m.winnerTeam == 1
                            ? AppColors.emerald400
                            : AppColors.indigo400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${m.team1DisplayName}: ${m.score1} pts',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                          color: AppColors.slate300, fontSize: 12),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('vs',
                        style:
                            TextStyle(color: AppColors.slate600, fontSize: 11)),
                  ),
                  Expanded(
                    child: Text(
                      '${m.team2DisplayName}: ${m.score2} pts',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          color: AppColors.slate300, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
