import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class RankBadge extends StatelessWidget {
  final int rank;

  const RankBadge({
    super.key,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    IconData? icon;

    if (rank == 1) {
      bg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
      icon = Icons.emoji_events;
    } else if (rank == 2) {
      bg = const Color(0xFF475569);
      border = const Color(0xFFCBD5E1);
      icon = Icons.looks_two;
    } else if (rank == 3) {
      bg = const Color(0xFF92400E);
      border = const Color(0xFFFBBF24);
      icon = Icons.looks_3;
    } else {
      bg = AppColors.slate800;
      border = AppColors.slate700;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: 16, color: Colors.white)
          : Text(
              '#$rank',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
    );
  }
}

class RankingListTile extends StatelessWidget {
  final int rank;
  final String title;
  final Widget subtitle;
  final int wins;
  final double winRate;
  final Color badgeBgColor;
  final Color badgeBorderColor;
  final Color badgeTextColor;

  const RankingListTile({
    super.key,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.wins,
    required this.winRate,
    required this.badgeBgColor,
    required this.badgeBorderColor,
    required this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank == 1
              ? AppColors.amber500.withValues(alpha: 0.6)
              : rank == 2
                  ? const Color(0xFF94A3B8).withValues(alpha: 0.4)
                  : rank == 3
                      ? const Color(0xFFB45309).withValues(alpha: 0.4)
                      : AppColors.slate800,
        ),
      ),
      child: Row(
        children: [
          RankBadge(rank: rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 3),
                subtitle,
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: badgeBorderColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$wins Vic',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${winRate.toStringAsFixed(0)}% efectividad',
                style: const TextStyle(fontSize: 10, color: AppColors.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RankingEmptyState extends StatelessWidget {
  final bool isTeams;
  final String periodText;
  final bool showResetButton;
  final VoidCallback onResetToAllTime;

  const RankingEmptyState({
    super.key,
    required this.isTeams,
    required this.periodText,
    required this.showResetButton,
    required this.onResetToAllTime,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTeams ? Icons.groups_outlined : Icons.person_search_outlined,
              size: 48,
              color: AppColors.slate600,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin partidas en $periodText',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'No se registraron juegos durante este mes.\nPuedes explorar otros meses o consultar el histórico general.',
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (showResetButton)
              OutlinedButton.icon(
                icon: const Icon(Icons.history,
                    size: 16, color: AppColors.emerald400),
                label: const Text(
                  'Ver Histórico Total',
                  style: TextStyle(color: AppColors.emerald400),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.emerald600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onResetToAllTime,
              ),
          ],
        ),
      ),
    );
  }
}
