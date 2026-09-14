import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/league.dart';
import '../services/league_service.dart';
import '../theme/app_colors.dart';
import '../widgets/header_widget.dart';
import '../widgets/team_card_widget.dart';
import '../widgets/rounds_history_widget.dart';
import '../widgets/reset_dialog.dart';

class DominoGameScreen extends StatefulWidget {
  final GameState gameState;
  final bool isLeagueMode;
  final String? leagueId;
  final List<String>? team1Members;
  final List<String>? team2Members;

  const DominoGameScreen({
    super.key,
    required this.gameState,
    this.isLeagueMode = false,
    this.leagueId,
    this.team1Members,
    this.team2Members,
  });

  @override
  State<DominoGameScreen> createState() => _DominoGameScreenState();
}

class _DominoGameScreenState extends State<DominoGameScreen> {
  bool _leagueMatchRecorded = false;

  @override
  void initState() {
    super.initState();
    widget.gameState.addListener(_checkLeagueMatchEnd);
  }

  @override
  void dispose() {
    widget.gameState.removeListener(_checkLeagueMatchEnd);
    super.dispose();
  }

  void _checkLeagueMatchEnd() {
    if (widget.isLeagueMode &&
        widget.gameState.isGameOver &&
        !_leagueMatchRecorded &&
        widget.leagueId != null) {
      _leagueMatchRecorded = true;

      final match = LeagueMatch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        team1DisplayName: widget.gameState.nombreE1,
        team2DisplayName: widget.gameState.nombreE2,
        team1Members: widget.team1Members ?? [widget.gameState.nombreE1],
        team2Members: widget.team2Members ?? [widget.gameState.nombreE2],
        score1: widget.gameState.totalE1,
        score2: widget.gameState.totalE2,
        winnerTeam: widget.gameState.ganador,
      );

      LeagueService().recordMatchForActiveLeague(match);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.slate300),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(
              widget.isLeagueMode ? Icons.emoji_events : Icons.sports_esports_outlined,
              size: 18,
              color: widget.isLeagueMode ? AppColors.amber300 : AppColors.emerald400,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isLeagueMode ? 'Partida Oficial de Liga' : 'Partida Casual',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.white),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.gameState,
          builder: (context, _) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado
                      HeaderWidget(gameState: widget.gameState),

                      const SizedBox(height: 12),

                      // Marcadores de Equipos (2 columnas)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TeamCardWidget(
                              teamNumber: 1,
                              gameState: widget.gameState,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TeamCardWidget(
                              teamNumber: 2,
                              gameState: widget.gameState,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Historial de Rondas
                      RoundsHistoryWidget(gameState: widget.gameState),

                      const SizedBox(height: 14),

                      // Botón Reiniciar Partida Completa
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => ResetConfirmDialog(
                                onConfirm: () {
                                  _leagueMatchRecorded = false;
                                  widget.gameState.reiniciarPartida();
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.rose950.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.rose800.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 15,
                                  color: AppColors.rose300,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Reiniciar Partida Completa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.rose300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
