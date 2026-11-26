import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'dialog_chrome.dart';

/// Diálogo unificado de eliminación de liga (dispositivo y opcionalmente servidor).
///
/// [onDelete] devuelve `null` en éxito o un mensaje de error.
/// [onDeleted] se invoca tras un éxito (refrescar listas, snackbars, etc.).
Future<void> showDeleteLeagueDialog(
  BuildContext context, {
  required String leagueId,
  required String leagueName,
  bool deleteOnServerDefault = false,
  String? prefillPin,
  required Future<String?> Function(String id,
          {String? pin, bool deleteOnServer})
      onDelete,
  VoidCallback? onDeleted,
  String title = 'Eliminar Liga',
  String? description,
}) {
  return showAppDialog(
    context,
    builder: (ctx) => _DeleteLeagueDialog(
      leagueId: leagueId,
      leagueName: leagueName,
      deleteOnServerDefault: deleteOnServerDefault,
      prefillPin: prefillPin,
      onDelete: onDelete,
      onDeleted: onDeleted,
      title: title,
      description: description,
    ),
  );
}

class _DeleteLeagueDialog extends StatefulWidget {
  final String leagueId;
  final String leagueName;
  final bool deleteOnServerDefault;
  final String? prefillPin;
  final Future<String?> Function(String id, {String? pin, bool deleteOnServer})
      onDelete;
  final VoidCallback? onDeleted;
  final String title;
  final String? description;

  const _DeleteLeagueDialog({
    required this.leagueId,
    required this.leagueName,
    required this.deleteOnServerDefault,
    required this.prefillPin,
    required this.onDelete,
    required this.onDeleted,
    required this.title,
    required this.description,
  });

  @override
  State<_DeleteLeagueDialog> createState() => _DeleteLeagueDialogState();
}

class _DeleteLeagueDialogState extends State<_DeleteLeagueDialog> {
  late final TextEditingController _pinController;
  late bool _deleteOnServer;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _deleteOnServer = widget.deleteOnServerDefault;
    _pinController = TextEditingController(text: widget.prefillPin ?? '');
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final err = await widget.onDelete(
      widget.leagueId,
      pin: _deleteOnServer ? _pinController.text.trim() : null,
      deleteOnServer: _deleteOnServer,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _errorText = err;
        _isSubmitting = false;
      });
    } else {
      Navigator.of(context).pop();
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.description ??
              '¿Deseas eliminar "${widget.leagueName}" (ID: ${widget.leagueId})?',
          style: const TextStyle(color: AppColors.slate300, fontSize: 13),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _deleteOnServer,
          onChanged: _isSubmitting
              ? null
              : (val) => setState(() => _deleteOnServer = val ?? false),
          title: const Text(
            'Eliminar también del servidor en la nube',
            style: TextStyle(color: AppColors.white, fontSize: 12),
          ),
          activeColor: Colors.redAccent,
        ),
        if (_deleteOnServer) ...[
          TextField(
            controller: _pinController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Clave/PIN para confirmar',
              hintText: 'PIN de la liga',
            ),
          ),
        ],
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
        const SizedBox(height: 18),
        DialogActionButtons(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _submit,
          confirmLabel: 'Eliminar',
          confirmColor: Colors.redAccent,
          confirmEnabled: !_isSubmitting,
          loading: _isSubmitting,
        ),
      ],
    );
  }
}

/// Eliminar liga directamente del servidor (acción admin con PIN).
Future<void> showDeleteServerLeagueDialog(
  BuildContext context, {
  required String leagueId,
  required String leagueName,
  required Future<String?> Function(String id, String pin) onDeleteOnServer,
  VoidCallback? onDeleted,
}) {
  return showAppDialog(
    context,
    builder: (ctx) => _DeleteServerLeagueDialog(
      leagueId: leagueId,
      leagueName: leagueName,
      onDeleteOnServer: onDeleteOnServer,
      onDeleted: onDeleted,
    ),
  );
}

class _DeleteServerLeagueDialog extends StatefulWidget {
  final String leagueId;
  final String leagueName;
  final Future<String?> Function(String id, String pin) onDeleteOnServer;
  final VoidCallback? onDeleted;

  const _DeleteServerLeagueDialog({
    required this.leagueId,
    required this.leagueName,
    required this.onDeleteOnServer,
    this.onDeleted,
  });

  @override
  State<_DeleteServerLeagueDialog> createState() =>
      _DeleteServerLeagueDialogState();
}

class _DeleteServerLeagueDialogState extends State<_DeleteServerLeagueDialog> {
  final _pinController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = 'Ingresa el PIN de la liga');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final err = await widget.onDeleteOnServer(widget.leagueId, pin);
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _errorText = err;
        _isSubmitting = false;
      });
    } else {
      Navigator.of(context).pop();
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Eliminar del Servidor (Admin)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Ingresa el PIN de "${widget.leagueName}" (${widget.leagueId}) para confirmar la eliminación definitiva del servidor en la nube.',
          style: const TextStyle(color: AppColors.slate300, fontSize: 12),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pinController,
          enabled: !_isSubmitting,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(
              color: AppColors.white, fontSize: 13, letterSpacing: 2),
          decoration: const InputDecoration(
            labelText: 'Clave de Acceso (PIN)',
            hintText: 'PIN de la liga',
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
        const SizedBox(height: 18),
        DialogActionButtons(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _submit,
          confirmLabel: 'Eliminar',
          confirmColor: Colors.redAccent,
          confirmEnabled: !_isSubmitting,
          loading: _isSubmitting,
        ),
      ],
    );
  }
}
