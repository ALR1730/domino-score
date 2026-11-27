import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../league_dialogs/dialog_chrome.dart';

enum RankingSource { device, server }

class RankingSourceSelector extends StatelessWidget {
  final RankingSource selected;
  final ValueChanged<RankingSource> onChanged;

  const RankingSourceSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDevice = selected == RankingSource.device;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _SourceChip(
              label: 'En este Dispositivo',
              icon: Icons.phone_android,
              isSelected: isDevice,
              onTap: () => onChanged(RankingSource.device),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SourceChip(
              label: 'En el Servidor',
              icon: Icons.cloud_outlined,
              isSelected: !isDevice,
              onTap: () => onChanged(RankingSource.server),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald600 : AppColors.slate900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.emerald500 : AppColors.slate800,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.slate400,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.slate400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RankingSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;

  const RankingSearchField({
    super.key,
    required this.controller,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13, color: AppColors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.slate900,
          hintText: 'Buscar por nombre o pareja...',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate500),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.slate400,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 16,
                    color: AppColors.slate400,
                  ),
                  onPressed: controller.clear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 14,
          ),
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
      ),
    );
  }
}

Future<void> showResetLeaderboardDialog(
  BuildContext context, {
  required Future<void> Function() onConfirmReset,
}) {
  return showAppDialog(
    context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.rose950.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.rose600.withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(
            Icons.delete_forever,
            color: AppColors.rose300,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '¿Borrar Clasificación?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Esta acción eliminará de forma permanente el historial de victorias de todos los equipos y jugadores.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.slate400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        DialogActionButtons(
          onCancel: () => Navigator.of(ctx).pop(),
          onConfirm: () {
            unawaited(onConfirmReset());
            Navigator.of(ctx).pop();
          },
          confirmLabel: 'Borrar Todo',
          confirmColor: AppColors.rose600,
        ),
      ],
    ),
  );
}
