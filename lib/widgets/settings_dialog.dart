import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';

class SettingsDialog extends StatefulWidget {
  final GameState gameState;

  const SettingsDialog({
    super.key,
    required this.gameState,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _controller;
  final List<int> _presets = [100, 150, 200, 300, 500];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.gameState.metaPuntos.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final val = int.tryParse(_controller.text);
    if (val != null && val > 0) {
      widget.gameState.setMetaPuntos(val);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, size: 20, color: AppColors.emerald400),
                SizedBox(width: 8),
                Text(
                  'Meta de Puntuación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Text(
              'Selecciona o ingresa la puntuación necesaria para ganar:',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.slate400,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 14),

            // Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _presets.map((p) {
                final isSelected = _controller.text == p.toString();
                return ChoiceChip(
                  label: Text(
                    '$p pts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.white : AppColors.slate300,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.emerald600,
                  backgroundColor: AppColors.slate800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppColors.emerald500 : AppColors.slate700,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _controller.text = p.toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Custom Input
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.slate950,
                hintText: '200',
                hintStyle: const TextStyle(color: AppColors.slate600),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 18),

            // Actions
            Row(
              children: [
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
                    child: const Text('Cancelar'),
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
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
