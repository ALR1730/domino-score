import 'package:flutter/material.dart';

import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import 'dialog_chrome.dart';

Future<void> showCreateLeagueDialog(
  BuildContext context, {
  required Future<void> Function(
          {required String name,
          required String pin,
          required List<String> participants})
      onCreate,
  VoidCallback? onCreated,
}) {
  return showAppDialog(
    context,
    barrierDismissible: false,
    builder: (ctx) =>
        _CreateLeagueDialog(onCreate: onCreate, onCreated: onCreated),
  );
}

class _CreateLeagueDialog extends StatefulWidget {
  final Future<void> Function(
      {required String name,
      required String pin,
      required List<String> participants}) onCreate;
  final VoidCallback? onCreated;

  const _CreateLeagueDialog({required this.onCreate, this.onCreated});

  @override
  State<_CreateLeagueDialog> createState() => _CreateLeagueDialogState();
}

class _CreateLeagueDialogState extends State<_CreateLeagueDialog> {
  final _nameController = TextEditingController();

  /// PIN sugerido: 4 dígitos aleatorios. Evita el viejo "1234" por defecto que
  /// hacía trivialmente adivinable cualquier liga recién creada.
  static String _randomPin() => LeagueService.generateSecurePin();

  late final TextEditingController _pinController =
      TextEditingController(text: _randomPin());
  final _participantsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _participantsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final parts = _participantsController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onCreate(
        name: name,
        pin: pin.isNotEmpty ? pin : _randomPin(),
        participants: parts,
      );
    } finally {
      if (mounted) Navigator.of(context).pop();
      widget.onCreated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.emerald400),
              SizedBox(width: 8),
              Text(
                'Crear Nueva Liga',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            enabled: !_isSubmitting,
            style: const TextStyle(color: AppColors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Nombre de la Liga',
              hintText: 'Ej. Liga de los Viernes',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Clave de Acceso (PIN)',
              hintText: 'Para entrar desde otros dispositivos',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _participantsController,
            enabled: !_isSubmitting,
            maxLines: 2,
            style: const TextStyle(color: AppColors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Participantes iniciales (separados por coma)',
              hintText: 'Carlos, Juan, Pedro, Luis, Maria',
            ),
          ),
          const SizedBox(height: 18),
          DialogActionButtons(
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: _submit,
            confirmLabel: 'Crear Liga',
            confirmColor: AppColors.emerald600,
            confirmEnabled: !_isSubmitting,
            loading: _isSubmitting,
          ),
        ],
      ),
    );
  }
}
