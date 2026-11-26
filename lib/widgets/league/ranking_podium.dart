import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class PodiumEntry {
  final String name;
  final int wins;

  const PodiumEntry({
    required this.name,
    required this.wins,
  });
}

class RankingPodium extends StatelessWidget {
  final List<PodiumEntry> entries;

  const RankingPodium({
    super.key,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) return const SizedBox.shrink();

    final first = entries[0];
    final second = entries[1];
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.slate900,
            AppColors.slate900.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate800),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PodiumStep(
            rank: 2,
            name: second.name,
            wins: second.wins,
            color: const Color(0xFF94A3B8),
            height: 65,
          ),
          _PodiumStep(
            rank: 1,
            name: first.name,
            wins: first.wins,
            color: AppColors.amber400,
            height: 85,
            isCenter: true,
          ),
          if (third != null)
            _PodiumStep(
              rank: 3,
              name: third.name,
              wins: third.wins,
              color: const Color(0xFFD97706),
              height: 52,
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _PodiumStep extends StatelessWidget {
  final int rank;
  final String name;
  final int wins;
  final Color color;
  final double height;
  final bool isCenter;

  const _PodiumStep({
    required this.rank,
    required this.name,
    required this.wins,
    required this.color,
    required this.height,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rank == 1 ? Icons.emoji_events : Icons.military_tech,
            size: isCenter ? 26 : 20,
            color: color,
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: TextStyle(
              fontSize: isCenter ? 12 : 11,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$wins Vic',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: isCenter ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
