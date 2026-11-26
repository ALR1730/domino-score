import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'dialog_chrome.dart';

Future<void> showAddParticipantDialog(
  BuildContext context, {
  required Future<void> Function(String name) onAdd,
}) {
  return showAppDialog(
    context,
    builder: (ctx) => _AddParticipantDialog(onAdd: onAdd),
  );
}

class _AddParticipantDialog extends StatefulWidget {
  final Future<void> Function(String name) onAdd;

  const _AddParticipantDialog({required this.onAdd});

  @override
  State<_AddParticipantDialog> createState() => _AddParticipantDialogState();
}

class _AddParticipantDialogState extends State<_AddParticipantDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop();
    widget.onAdd(name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nuevo Participante',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.white),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Nombre del jugador (ej. María)',
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        DialogActionButtons(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _submit,
          confirmLabel: 'Agregar',
          confirmColor: AppColors.emerald600,
        ),
      ],
    );
  }
}
