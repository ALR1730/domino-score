import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import 'domino_game_screen.dart';
import 'league/global_ranking_screen.dart';
import 'league/league_home_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // Header Icon and Title
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.slate900,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald500.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.casino_outlined,
                        size: 48,
                        color: AppColors.emerald400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Dominó Score',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Selecciona el modo de juego para comenzar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.slate400,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Card: MODO CASUAL
                  _buildModeCard(
                    context: context,
                    icon: Icons.sports_esports_outlined,
                    iconColor: AppColors.emerald400,
                    title: 'Modo Casual',
                    badgeText: 'Partida Rápida',
                    badgeColor: AppColors.emerald500,
                    description: 'Juega una partida rápida al instante. Nombres libres, sin tablas de clasificación obligatorias.',
                    onTap: () {
                      final casualGameState = GameState();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => DominoGameScreen(
                            gameState: casualGameState,
                            isLeagueMode: false,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Card: MODO LIGA
                  _buildModeCard(
                    context: context,
                    icon: Icons.emoji_events,
                    iconColor: AppColors.amber300,
                    title: 'Modo Liga',
                    badgeText: 'Competitivo & Clave',
                    badgeColor: AppColors.amber600,
                    description: 'Crea o únete a una liga con clave PIN. Registra participantes, arma parejas oficiales y compite por las tablas de clasificación.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const LeagueHomeScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Button: Ranking General del Servidor
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const GlobalRankingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.public, size: 18, color: AppColors.emerald400),
                    label: const Text(
                      'Ver Ranking General del Servidor',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate200),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.slate900,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.slate800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.slate800, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.slate950,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, size: 24, color: iconColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: iconColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
