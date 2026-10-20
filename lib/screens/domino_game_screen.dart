import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/leaderboard_entry.dart';
import '../models/league.dart';
import '../services/leaderboard_service.dart';
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
  // Registro único de resultado por sesión de pantalla (se limpia al
  // reiniciar la partida para permitir registrar la siguiente).
  bool _resultRecorded = false;

  @override
  void initState() {
    super.initState();
    widget.gameState.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    widget.gameState.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    // Evaluar solo con el estado completamente cargado. Evita que el listener
    // actúe con datos desactualizados durante la inicialización asíncrona.
    if (!widget.gameState.isLoaded) return;

    // Transición única "en juego" → "terminada" (bandera consumible: no se
    // vuelve a disparar en cambios posteriores del mismo estado).
    if (!widget.gameState.consumeJustFinished()) return;
    if (_resultRecorded) return;

    // Seguridad: no registrar partidas con puntaje total 0
    final score1 = widget.gameState.totalE1;
    final score2 = widget.gameState.totalE2;
    if (score1 <= 0 && score2 <= 0) return;

    _resultRecorded = true;

    final members1 = widget.team1Members ??
        NameParser.extractMembers(widget.gameState.nombreE1);
    final members2 = widget.team2Members ??
        NameParser.extractMembers(widget.gameState.nombreE2);

    final match = LeagueMatch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      team1DisplayName: widget.gameState.nombreE1,
      team2DisplayName: widget.gameState.nombreE2,
      team1Members: members1,
      team2Members: members2,
      score1: score1,
      score2: score2,
      winnerTeam: widget.gameState.ganador,
    );

    _recordResults(match);
  }

  /// Registra el resultado en la clasificación de este dispositivo (siempre)
  /// y, en modo liga, en la liga capturada al inicio de la partida. El
  /// SnackBar se muestra al terminar, con un mensaje según lo que realmente
  /// se registró.
  Future<void> _recordResults(LeagueMatch match) async {
    final recordedLocally = await LeaderboardService().recordMatch(match);

    bool recordedInLeague = false;
    final leagueId = widget.leagueId;
    if (widget.isLeagueMode && leagueId != null && leagueId.isNotEmpty) {
      recordedInLeague = await LeagueService().recordMatchToLeague(leagueId, match);
    }

    if (!mounted) return;

    final winnerName = widget.gameState.ganador == 1
        ? widget.gameState.nombreE1
        : widget.gameState.nombreE2;

    String message;
    if (widget.isLeagueMode && recordedInLeague) {
      message = '🏆 ¡$winnerName gana! Partida registrada en la liga.';
    } else if (widget.isLeagueMode) {
      message =
          '🏆 ¡$winnerName gana! La liga ya no existe en este dispositivo.';
    } else if (recordedLocally) {
      message =
          '🏆 ¡$winnerName gana! Sumado a la clasificación de este dispositivo.';
    } else {
      message = '🏆 ¡$winnerName gana!';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF065F46),
        duration: const Duration(seconds: 4),
      ),
    );
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
                                  _resultRecorded = false;
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
