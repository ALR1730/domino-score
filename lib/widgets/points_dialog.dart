import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import 'winner_dialog.dart';

class PointsDialog extends StatefulWidget {
  final int equipo;
  final GameState gameState;
  final int? editIndex; // null if adding new round

  const PointsDialog({
    super.key,
    required this.equipo,
    required this.gameState,
    this.editIndex,
  });

  @override
  State<PointsDialog> createState() => _PointsDialogState();
}

class _PointsDialogState extends State<PointsDialog> {
  late TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialPoints = widget.editIndex != null
        ? widget.gameState.rondas[widget.editIndex!].puntos.toString()
        : '';
    _controller = TextEditingController(text: initialPoints);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addQuick(int val) {
    final current = int.tryParse(_controller.text) ?? 0;
    final updated = current + val;
    setState(() {
      _controller.text = updated.toString();
      _errorMessage = null;
    });
  }

  void _save() {
    final val = int.tryParse(_controller.text);
    if (val == null || val <= 0) {
      setState(() {
        _errorMessage = 'Ingresa una cantidad de puntos válida.';
      });
      return;
    }

    if (widget.editIndex != null) {
      widget.gameState.editarRonda(widget.editIndex!, val);
    } else {
      widget.gameState.agregarRonda(widget.equipo, val);
    }

    Navigator.of(context).pop();

    // Check if team reached goal and trigger celebration
    if (widget.gameState.isGameOver) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WinnerDialog(gameState: widget.gameState),
      );
    }
  }

  void _delete() {
    if (widget.editIndex != null) {
      widget.gameState.eliminarRonda(widget.editIndex!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editIndex != null;
    final teamName = widget.equipo == 1
        ? widget.gameState.nombreE1
        : widget.gameState.nombreE2;

    final title = isEditing
        ? 'Editar Ronda #${widget.editIndex! + 1}'
        : 'Puntos para $teamName';

    return Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.slate800),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 14),

            // Label
            const Text(
              'Puntos de la mano:',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.slate400,
              ),
            ),
            const SizedBox(height: 6),

            // Score Input
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.slate950,
                hintText: '0',
                hintStyle: const TextStyle(color: AppColors.slate600),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.slate700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.slate700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.emerald500, width: 2),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.rose300,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Quick add buttons (+25, +30, +50, +60)
            Row(
              children: [25, 30, 50, 60].map((val) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: OutlinedButton(
                      onPressed: () => _addQuick(val),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.slate800,
                        foregroundColor: AppColors.slate300,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: AppColors.slate700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        '+$val',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // Dialog Actions
            Row(
              children: [
                if (isEditing) ...[
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.rose300),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.rose950.withValues(alpha: 0.5),
                      side: BorderSide(color: AppColors.rose600.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.slate800,
                      foregroundColor: AppColors.slate300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald600,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
