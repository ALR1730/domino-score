import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import 'points_dialog.dart';

class RoundsHistoryWidget extends StatelessWidget {
  final GameState gameState;

  const RoundsHistoryWidget({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    final rondas = gameState.rondas;
    final isGameOver = gameState.isGameOver;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header of History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HISTORIAL DE RONDAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.slate400,
                ),
              ),

              // Game Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isGameOver
                      ? AppColors.amber950.withValues(alpha: 0.8)
                      : AppColors.emerald950.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isGameOver
                        ? AppColors.amber600.withValues(alpha: 0.8)
                        : AppColors.emerald500.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isGameOver ? '¡Ganó ${gameState.ganadorNombre}!' : 'En juego',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isGameOver ? FontWeight.bold : FontWeight.w500,
                    color: isGameOver ? AppColors.amber300 : AppColors.emerald400,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // List or Empty Placeholder
          if (rondas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Sin puntos registrados aún.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rondas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                // Reverse chronological index
                final realIndex = rondas.length - 1 - i;
                final round = rondas[realIndex];
                final isTeam1 = round.equipo == 1;
                final teamName =
                    isTeam1 ? gameState.nombreE1 : gameState.nombreE2;
                final tagColor =
                    isTeam1 ? AppColors.emerald400 : AppColors.indigo400;
                final tagBorder = isTeam1
                    ? AppColors.emerald500.withValues(alpha: 0.3)
                    : AppColors.indigo500.withValues(alpha: 0.3);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => PointsDialog(
                          equipo: round.equipo,
                          gameState: gameState,
                          editIndex: realIndex,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.slate950.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.slate800,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${realIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: AppColors.slate500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                teamName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.slate300,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tagBorder),
                            ),
                            child: Text(
                              '+${round.puntos}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: tagColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 12),

          // Hint Footer
          const Text(
            'Toca cualquier ronda registrada para modificarla o corregirla.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
