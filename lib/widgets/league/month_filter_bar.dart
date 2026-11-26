import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

const List<String> _monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

String formatMonthYear(DateTime dt) {
  final name = _monthNames[dt.month - 1];
  return '$name ${dt.year}';
}

class MonthFilterBar extends StatelessWidget {
  final DateTime? selectedMonth;
  final List<DateTime> availableMonths;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onOpenPicker;

  const MonthFilterBar({
    super.key,
    required this.selectedMonth,
    required this.availableMonths,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onOpenPicker,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = selectedMonth == null
        ? -1
        : availableMonths.indexWhere(
            (d) =>
                d.year == selectedMonth!.year &&
                d.month == selectedMonth!.month,
          );

    final canGoPrev = availableMonths.isNotEmpty &&
        (selectedMonth == null || currentIndex < availableMonths.length - 1);
    final canGoNext = selectedMonth != null;

    final displayText = selectedMonth != null
        ? formatMonthYear(selectedMonth!)
        : 'Histórico Total';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate800.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate700.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            color: canGoPrev ? AppColors.white : AppColors.slate600,
            onPressed: canGoPrev ? onPrevMonth : null,
            tooltip: 'Mes anterior',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: InkWell(
              onTap: onOpenPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selectedMonth != null
                          ? Icons.calendar_month
                          : Icons.history,
                      size: 16,
                      color: AppColors.emerald400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayText,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_drop_down,
                        size: 18, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            color: canGoNext ? AppColors.white : AppColors.slate600,
            onPressed: canGoNext ? onNextMonth : null,
            tooltip: 'Mes siguiente',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

Future<void> showMonthPickerSheet(
  BuildContext context, {
  required DateTime? selectedMonth,
  required List<DateTime> availableMonths,
  required ValueChanged<DateTime?> onSelectMonth,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month,
                        color: AppColors.emerald400, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Seleccionar Período de Ranking',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.slate800),
              ListTile(
                leading:
                    const Icon(Icons.all_inclusive, color: AppColors.amber400),
                title: const Text(
                  'Histórico Total (Todas las partidas)',
                  style: TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w600),
                ),
                trailing: selectedMonth == null
                    ? const Icon(Icons.check_circle,
                        color: AppColors.emerald400)
                    : null,
                onTap: () {
                  onSelectMonth(null);
                  Navigator.pop(ctx);
                },
              ),
              if (availableMonths.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay meses con partidas registradas aún.',
                    style: TextStyle(color: AppColors.slate400, fontSize: 13),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableMonths.length,
                    itemBuilder: (context, i) {
                      final dt = availableMonths[i];
                      final isSelected = selectedMonth != null &&
                          selectedMonth.year == dt.year &&
                          selectedMonth.month == dt.month;

                      return ListTile(
                        leading: Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: isSelected
                              ? AppColors.emerald400
                              : AppColors.slate400,
                        ),
                        title: Text(
                          formatMonthYear(dt),
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.emerald400
                                : AppColors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.emerald400)
                            : null,
                        onTap: () {
                          onSelectMonth(dt);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
