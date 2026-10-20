import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogos compartidos de ligas (crear / unirse / eliminar).
///
/// Antes estas tres pantallas tenían copias casi idénticas de estos
/// diálogos (`league_home_screen.dart` y `league_manager_screen.dart`);
/// ahora existen en un solo lugar. Los callbacks mantienen a los diálogos
/// desacoplados del servicio, y los `TextEditingController` se liberan
/// correctamente en `dispose` (antes se filtraban en cada apertura).

/// Chrome común de diálogo: fondo slate900, borde redondeado 20 y padding.
Future<void> showAppDialog(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.slate800),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: builder(ctx),
      ),
    ),
  );
}

/// Fila "Cancelar / Acción principal" usada por todos los diálogos de liga.
class DialogActionButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final Color confirmColor;
  final bool confirmEnabled;
  final bool loading;

  const DialogActionButtons({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
    required this.confirmColor,
    this.confirmEnabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: confirmEnabled ? onCancel : null,
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.slate400)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: confirmEnabled ? onConfirm : null,
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    confirmLabel,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Crear liga
// ---------------------------------------------------------------------------

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
  final _pinController = TextEditingController(text: '1234');
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
        pin: pin.isNotEmpty ? pin : '1234',
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

// ---------------------------------------------------------------------------
// Unirse a una liga
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Agregar participante
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Eliminar liga
// ---------------------------------------------------------------------------

/// Diálogo unificado de eliminación (antes había 3 copias casi idénticas).
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

// ---------------------------------------------------------------------------
// Eliminar liga directamente del servidor (acción admin con PIN)
// ---------------------------------------------------------------------------

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
