import 'package:flutter/material.dart';
import '../models/medication.dart';

class MedicationCard extends StatelessWidget {
  final Medication medication;
  final String time;

  /// Estado de ESTA dosis (no del medicamento completo)
  final bool isTaken;

  final VoidCallback onTap;
  final VoidCallback onTaken;
  final VoidCallback onPostpone;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.time,
    required this.isTaken,
    required this.onTap,
    required this.onTaken,
    required this.onPostpone,
  });

  @override
  Widget build(BuildContext context) {
    // Ahora el estado visual depende de isTaken, no de medication.status
    final String statusText = isTaken ? 'Tomado' : 'Pendiente';
    final Color statusColor = isTaken ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Circulito de color
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nombre, dosis, presentación
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$time · ${medication.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medication.dose} · ${medication.presentation}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chip de estado + botones
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          // Si ya está tomado, no tiene sentido posponer
                          onPressed: isTaken ? null : onPostpone,
                          child: const Text('Posponer'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          // Si ya está tomado, deshabilitamos el botón
                          onPressed: isTaken ? null : onTaken,
                          child: Text(isTaken ? 'Tomado' : 'Tomar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
