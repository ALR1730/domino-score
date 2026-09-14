import 'package:flutter/material.dart';
import '../../models/game_state.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import '../domino_game_screen.dart';

class MatchSetupScreen extends StatefulWidget {
  final League league;

  const MatchSetupScreen({super.key, required this.league});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  String? _team1Player1;
  String? _team1Player2;
  String? _team2Player1;
  String? _team2Player2;

  int _metaPuntos = 200;
  final TextEditingController _customPlayerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.league.participants;
    if (p.length >= 4) {
      _team1Player1 = p[0];
      _team1Player2 = p[1];
      _team2Player1 = p[2];
      _team2Player2 = p[3];
    } else if (p.length >= 2) {
      _team1Player1 = p[0];
      _team1Player2 = p.length > 1 ? p[1] : null;
    }
  }

  @override
  void dispose() {
    _customPlayerController.dispose();
    super.dispose();
  }

  void _addQuickParticipant() {
    final name = _customPlayerController.text.trim();
    if (name.isNotEmpty) {
      LeagueService().addParticipantToActiveLeague(name);
      _customPlayerController.clear();
      setState(() {});
    }
  }

  bool _isSelectionValid() {
    if (_team1Player1 == null ||
        _team1Player2 == null ||
        _team2Player1 == null ||
        _team2Player2 == null) {
      return false;
    }
    final set = {
      _team1Player1,
      _team1Player2,
      _team2Player1,
      _team2Player2,
    };
    return set.length == 4;
  }

  void _startMatch() {
    if (!_isSelectionValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar 4 jugadores distintos (2 por equipo).'),
          backgroundColor: AppColors.rose600,
        ),
      );
      return;
    }

    final team1Name = '$_team1Player1 & $_team1Player2';
    final team2Name = '$_team2Player1 & $_team2Player2';

    final gameState = GameState();
    gameState.setNombreE1(team1Name);
    gameState.setNombreE2(team2Name);
    gameState.setMetaPuntos(_metaPuntos);
    gameState.reiniciarPartida();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => DominoGameScreen(
          gameState: gameState,
          isLeagueMode: true,
          leagueId: widget.league.id,
          team1Members: [_team1Player1!, _team1Player2!],
          team2Members: [_team2Player1!, _team2Player2!],
        ),
      ),
    );
  }

  Widget _buildPlayerDropdown({
    required String label,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    required Color color,
  }) {
    final participants = widget.league.participants;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate950,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: participants.contains(selectedValue) ? selectedValue : null,
          hint: Text(
            label,
            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
          dropdownColor: AppColors.slate900,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: participants.map((p) {
            return DropdownMenuItem<String>(
              value: p,
              child: Text(p),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.league.participants;

    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.slate300),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Nueva Partida: ${widget.league.name}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning if fewer than 4 participants
            if (participants.length < 4) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber950.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amber600.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.amber300, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Se requieren al menos 4 participantes para una partida oficial de dominó por parejas. Tienes ${participants.length}.',
                        style: const TextStyle(fontSize: 12, color: AppColors.amber300),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Add participant input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customPlayerController,
                    style: const TextStyle(fontSize: 13, color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Agregar nuevo jugador a la liga...',
                      hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.slate900,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.slate800),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.slate800),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.emerald500),
                      ),
                    ),
                    onSubmitted: (_) => _addQuickParticipant(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addQuickParticipant,
                  icon: const Icon(Icons.add, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.emerald600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Team 1 Configuration Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, size: 16, color: AppColors.emerald400),
                      SizedBox(width: 6),
                      Text(
                        'EQUIPO 1 (Pareja Esmeralda)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPlayerDropdown(
                    label: 'Seleccionar Jugador 1',
                    selectedValue: _team1Player1,
                    onChanged: (val) => setState(() => _team1Player1 = val),
                    color: AppColors.emerald500,
                  ),
                  const SizedBox(height: 8),
                  _buildPlayerDropdown(
                    label: 'Seleccionar Jugador 2',
                    selectedValue: _team1Player2,
                    onChanged: (val) => setState(() => _team1Player2 = val),
                    color: AppColors.emerald500,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Team 2 Configuration Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, size: 16, color: AppColors.indigo400),
                      SizedBox(width: 6),
                      Text(
                        'EQUIPO 2 (Pareja Índigo)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.indigo400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPlayerDropdown(
                    label: 'Seleccionar Jugador 3',
                    selectedValue: _team2Player1,
                    onChanged: (val) => setState(() => _team2Player1 = val),
                    color: AppColors.indigo500,
                  ),
                  const SizedBox(height: 8),
                  _buildPlayerDropdown(
                    label: 'Seleccionar Jugador 4',
                    selectedValue: _team2Player2,
                    onChanged: (val) => setState(() => _team2Player2 = val),
                    color: AppColors.indigo500,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Target Points Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Puntos para Ganar (Meta):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate300),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [100, 150, 200, 300, 500].map((meta) {
                      final isSelected = _metaPuntos == meta;
                      return ChoiceChip(
                        label: Text('$meta pts'),
                        selected: isSelected,
                        selectedColor: AppColors.emerald600,
                        backgroundColor: AppColors.slate800,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.slate300,
                        ),
                        onSelected: (_) => setState(() => _metaPuntos = meta),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Start Match Button
            ElevatedButton.icon(
              onPressed: _startMatch,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text(
                'Comenzar Partida Oficial',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
