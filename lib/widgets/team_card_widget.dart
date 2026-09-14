import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import 'points_dialog.dart';

class TeamCardWidget extends StatefulWidget {
  final int teamNumber; // 1 or 2
  final GameState gameState;

  const TeamCardWidget({
    super.key,
    required this.teamNumber,
    required this.gameState,
  });

  @override
  State<TeamCardWidget> createState() => _TeamCardWidgetState();
}

class _TeamCardWidgetState extends State<TeamCardWidget> {
  late TextEditingController _nameController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.teamNumber == 1
          ? widget.gameState.nombreE1
          : widget.gameState.nombreE2,
    );
  }

  @override
  void didUpdateWidget(covariant TeamCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentName = widget.teamNumber == 1
        ? widget.gameState.nombreE1
        : widget.gameState.nombreE2;
    if (_nameController.text != currentName && !_focusNode.hasFocus) {
      _nameController.text = currentName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveName() {
    if (widget.teamNumber == 1) {
      widget.gameState.setNombreE1(_nameController.text);
    } else {
      widget.gameState.setNombreE2(_nameController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTeam1 = widget.teamNumber == 1;
    final accentColor = isTeam1 ? AppColors.emerald500 : AppColors.indigo500;
    final buttonColor = isTeam1 ? AppColors.emerald600 : AppColors.indigo600;
    final total = isTeam1 ? widget.gameState.totalE1 : widget.gameState.totalE2;
    final roundsCount = isTeam1
        ? widget.gameState.rondasE1Count
        : widget.gameState.rondasE2Count;
    final isWinner = widget.gameState.ganador == widget.teamNumber;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner
              ? AppColors.amber300
              : AppColors.slate800,
          width: isWinner ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          if (isWinner)
            BoxShadow(
              color: AppColors.amber300.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Editable Team Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: TextField(
                  controller: _nameController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _focusNode.hasFocus
                        ? AppColors.white
                        : AppColors.slate300,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: _focusNode.hasFocus
                            ? accentColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: accentColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _saveName(),
                  onEditingComplete: () {
                    _saveName();
                    _focusNode.unfocus();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Total Score
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: AppColors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),

          // TOTAL label
          const Text(
            'TOTAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.slate400,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          // Rounds count
          Text(
            '$roundsCount ${roundsCount == 1 ? "ronda" : "rondas"}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.slate400,
            ),
          ),

          const SizedBox(height: 12),

          // + Sumar Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => PointsDialog(
                    equipo: widget.teamNumber,
                    gameState: widget.gameState,
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text(
                'Sumar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
