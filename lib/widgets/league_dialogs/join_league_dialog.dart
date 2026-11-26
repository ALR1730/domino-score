import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'dialog_chrome.dart';

/// Modo sin [leagueId]: el usuario busca por nombre/código + PIN.
/// Modo con [leagueId] (gestor de ligas): liga preseleccionada, solo PIN.
Future<void> showJoinLeagueDialog(
  BuildContext context, {
  String? leagueId,
  String? leagueName,
  required Future<String?> Function(String nameOrId, String pin) onJoin,
  VoidCallback? onJoined,
}) {
  return showAppDialog(
    context,
    builder: (ctx) => _JoinLeagueDialog(
      leagueId: leagueId,
      leagueName: leagueName,
      onJoin: onJoin,
      onJoined: onJoined,
    ),
  );
}

class _JoinLeagueDialog extends StatefulWidget {
  final String? leagueId;
  final String? leagueName;
  final Future<String?> Function(String nameOrId, String pin) onJoin;
  final VoidCallback? onJoined;

  const _JoinLeagueDialog({
    this.leagueId,
    this.leagueName,
    required this.onJoin,
    this.onJoined,
  });

  @override
  State<_JoinLeagueDialog> createState() => _JoinLeagueDialogState();
}

class _JoinLeagueDialogState extends State<_JoinLeagueDialog> {
  late final TextEditingController _searchController;
  final _pinController = TextEditingController();
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.leagueId ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    final target = widget.leagueId ?? _searchController.text.trim();

    if (widget.leagueId == null && target.isEmpty) {
      setState(() => _error = 'Ingresa el nombre o código de la liga');
      return;
    }
    if (pin.isEmpty) {
      setState(() => _error = 'Ingresa el PIN de la liga');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final err = await widget.onJoin(target, pin);
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _isSubmitting = false;
      });
    } else {
      Navigator.of(context).pop();
      widget.onJoined?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPreFilled = widget.leagueId != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.vpn_key_outlined,
                color: AppColors.amber300, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPreFilled
                    ? 'Unirse a "${widget.leagueName ?? widget.leagueId}"'
                    : 'Unirse a una Liga',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isPreFilled
              ? 'Código de Liga: ${widget.leagueId}\nIngresa la clave de acceso para registrarla en este dispositivo.'
              : 'Ingresa el nombre o código de la liga y la clave de acceso compartida.',
          style: const TextStyle(fontSize: 11, color: AppColors.slate400),
        ),
        const SizedBox(height: 14),
        if (!isPreFilled) ...[
          TextField(
            controller: _searchController,
            enabled: !_isSubmitting,
            style: const TextStyle(color: AppColors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Nombre o Código de la Liga (ej. LIG-1001)',
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _pinController,
          enabled: !_isSubmitting,
          obscureText: !isPreFilled,
          autofocus: isPreFilled,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: AppColors.white,
            fontSize: isPreFilled ? 14 : 13,
            letterSpacing: isPreFilled ? 3 : null,
          ),
          decoration: const InputDecoration(
            labelText: 'Clave de Acceso (PIN)',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.rose300, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 18),
        DialogActionButtons(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _submit,
          confirmLabel: isPreFilled ? 'Unirse' : 'Entrar',
          confirmColor: AppColors.amber600,
          confirmEnabled: !_isSubmitting,
          loading: _isSubmitting,
        ),
      ],
    );
  }
}
