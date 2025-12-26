import 'package:flutter/material.dart';

class DayStrip extends StatelessWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const DayStrip({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    // Lunes de la semana actual
    final start = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );

    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return SizedBox(
      height: 92, // un poquito más para evitar apretujones
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = DateUtils.isSameDay(day, selectedDay);
          final isToday = DateUtils.isSameDay(day, today);

          final bgColor = isSelected ? theme.colorScheme.primary : Colors.white;
          final fgColor = isSelected ? Colors.white : Colors.black;
          final labelColor = isSelected ? Colors.white : Colors.grey.shade700;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onDaySelected(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56, // fijo
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: isToday ? 1.4 : 1.0,
                    color: isToday
                        ? theme.colorScheme.secondary
                        : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Label (Lun, Mar, Mié...)
                    SizedBox(
                      height: 16,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: labelColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Día del mes
                    SizedBox(
                      height: 26,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: fgColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
