import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../screens/leaderboard_screen.dart';
import '../theme/app_colors.dart';

class WinnerDialog extends StatelessWidget {
  final GameState gameState;

  const WinnerDialog({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    final winnerName = gameState.ganadorNombre;
    final winnerTeam = gameState.ganador;
    final winnerColor =
        winnerTeam == 1 ? AppColors.emerald400 : AppColors.indigo400;

    return Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.amber600, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.amber950.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.amber600, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber600.withValues(alpha: 0.3),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                color: AppColors.amber300,
                size: 42,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              '¡PARTIDA FINALIZADA!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.amber300,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '¡Ganó $winnerName!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: winnerColor,
              ),
            ),

            const SizedBox(height: 8),

            // Saved to leaderboard badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.emerald950.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 13, color: AppColors.emerald400),
                  SizedBox(width: 5),
                  Text(
                    'Guardado en Clasificación',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Scoreboard Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate950,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate800),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        gameState.nombreE1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${gameState.totalE1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald400,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: AppColors.slate800,
                  ),
                  Column(
                    children: [
                      Text(
                        gameState.nombreE2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${gameState.totalE2}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.indigo400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    gameState.reiniciarPartida();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald600,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Iniciar Nueva Partida',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const LeaderboardScreen()),
                    );
                  },
                  icon: const Icon(Icons.emoji_events, size: 16, color: AppColors.amber300),
                  label: const Text(
                    'Ver Tabla de Clasificación',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate100,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.slate800,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: AppColors.slate700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.slate400,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Ver Marcador Final',
                    style: TextStyle(fontSize: 12),
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
