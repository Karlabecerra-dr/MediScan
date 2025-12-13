import 'package:flutter/material.dart';

// Widget que muestra una franja horizontal con los días de la semana.
// Permite seleccionar un día y notificar el cambio al padre.
class DayStrip extends StatelessWidget {
  // Día actualmente seleccionado
  final DateTime selectedDay;

  // Callback que se ejecuta al seleccionar un día
  final ValueChanged<DateTime> onDaySelected;

  const DayStrip({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    // Fecha actual
    final today = DateTime.now();

    // Calcula el lunes de la semana actual
    final start = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );

    // Genera la lista de los 7 días de la semana (lunes a domingo)
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    // Etiquetas visibles para cada día
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        // Scroll horizontal
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),

        // Construcción de cada día
        itemBuilder: (_, index) {
          final day = days[index];

          // Indica si este día es el seleccionado
          final isSelected = DateUtils.isSameDay(day, selectedDay);

          // Indica si este día corresponde a hoy
          final isToday = DateUtils.isSameDay(day, today);

          return GestureDetector(
            // Al tocar, se notifica el día seleccionado
            onTap: () => onDaySelected(day),
            child: AnimatedContainer(
              // Animación suave al cambiar selección
              duration: const Duration(milliseconds: 200),
              width: 56,
              constraints: const BoxConstraints(maxWidth: 56),
              decoration: BoxDecoration(
                // Color distinto si está seleccionado
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  // Borde especial para el día actual
                  color: isToday
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.grey.shade300,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Etiqueta del día (Lun, Mar, etc.)
                  Text(
                    labels[index],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Número del día del mes
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },

        // Separación entre elementos
        separatorBuilder: (_, __) => const SizedBox(width: 8),

        // Total de días mostrados
        itemCount: days.length,
      ),
    );
  }
}
