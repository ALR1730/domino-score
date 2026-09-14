import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../screens/leaderboard_screen.dart';
import '../theme/app_colors.dart';
import 'settings_dialog.dart';

class HeaderWidget extends StatelessWidget {
  final GameState gameState;

  const HeaderWidget({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Title
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.emerald950.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.casino_outlined,
                    color: AppColors.emerald400,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dominó Score',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Control de puntuaciones',
                        style: TextStyle(
                          color: AppColors.slate400,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Leaderboard Trophy Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const LeaderboardScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.amber950.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amber600.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 17,
                  color: AppColors.amber300,
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Meta Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SettingsDialog(gameState: gameState),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate700),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings_outlined,
                      size: 13,
                      color: AppColors.slate300,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Meta: ',
                      style: TextStyle(
                        color: AppColors.slate300,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${gameState.metaPuntos}',
                      style: const TextStyle(
                        color: AppColors.emerald400,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
