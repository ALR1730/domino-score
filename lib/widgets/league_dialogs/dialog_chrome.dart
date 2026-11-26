import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

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
