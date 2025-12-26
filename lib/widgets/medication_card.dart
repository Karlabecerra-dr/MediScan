import 'package:flutter/material.dart';

class MedicationCard extends StatelessWidget {
  // Datos visibles del ítem
  final String timeLabel;
  final String medicationName;
  final String dosageLabel; // ej: "100 mg · Tableta"
  final String statusLabel; // ej: "Pendiente" / "Tomado"

  // Acciones
  final VoidCallback onTake;
  final VoidCallback onSnooze;

  const MedicationCard({
    super.key,
    required this.timeLabel,
    required this.medicationName,
    required this.dosageLabel,
    required this.statusLabel,
    required this.onTake,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isPending = statusLabel.toLowerCase().contains('pend');
    final isTaken = statusLabel.toLowerCase().contains('tom');

    final chipBg = isTaken
        ? Colors.green.shade100
        : (isPending
              ? Colors.orange.shade100
              : theme.colorScheme.secondaryContainer);

    final chipFg = isTaken
        ? Colors.green.shade800
        : (isPending
              ? Colors.orange.shade800
              : theme.colorScheme.onSecondaryContainer);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono "píldora"
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha((0.12 * 255).round()),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.medication_liquid, // se ve más “medicamento” que un punto
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),

          // Contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hora + estado
                Row(
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: chipFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Nombre medicamento
                Text(
                  medicationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),

                // Dosis/presentación
                Text(
                  dosageLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),

                const SizedBox(height: 14),

                // Botones: misma “altura visual”
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onSnooze,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Posponer'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: onTake,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tomar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
